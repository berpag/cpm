// lib/data/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/config/constants.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // --- Métodos de Configuración de Fiat ---
  static Stream<Set<String>> getFiatListStream() {
    final userId = _userId;
    if (userId == null) return Stream.value({});

    final docRef = _db.collection('users').doc(userId).collection('config').doc('fiat_currencies');

    return docRef.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) {
        await docRef.set({'tickers': kFiatTickers.toList()});
        return kFiatTickers;
      }
      final data = snapshot.data();
      final tickers = List<String>.from(data?['tickers'] ?? []);
      return tickers.toSet();
    });
  }

  static Future<void> updateFiatList(Set<String> newFiatList) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    final docRef = _db.collection('users').doc(userId).collection('config').doc('fiat_currencies');
    await docRef.set({'tickers': newFiatList.toList()});
  }

  // --- Métodos de Transacciones ---
  static Future<void> addTransaction(app_models.Transaction transaction) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    await _db.collection('users').doc(userId).collection('transactions').add(transaction.toFirestore());
  }

  static Stream<List<app_models.Transaction>> getTransactionsStream() {
    final userId = _userId;
    if (userId == null) return Stream.value([]);
    return _db.collection('users').doc(userId).collection('transactions').orderBy('date', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => app_models.Transaction.fromFirestore(doc.data())).toList();
    });
  }

  static Future<void> addTransactionsInBatch(List<app_models.Transaction> transactions) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    if (transactions.isEmpty) return;
    final collectionRef = _db.collection('users').doc(userId).collection('transactions');
    final WriteBatch batch = _db.batch();
    for (final transaction in transactions) {
      final docRef = collectionRef.doc(); 
      batch.set(docRef, transaction.toFirestore());
    }
    await batch.commit();
  }

  static Future<void> deleteTransactionsBySource(String sourceAccount) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    print("[FirestoreService] Buscando transacciones de '$sourceAccount' para borrar...");
    final collectionRef = _db.collection('users').doc(userId).collection('transactions');
    var query = collectionRef.where('sourceAccount', isEqualTo: sourceAccount);
    var snapshot = await query.limit(500).get();
    while (snapshot.docs.isNotEmpty) {
      final WriteBatch batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("[FirestoreService] Lote de ${snapshot.docs.length} transacciones de '$sourceAccount' eliminadas.");
      snapshot = await query.limit(500).get();
    }
  }

  // --- Métodos de Datos Crudos y Calculados ---
  static Future<void> saveRawCsvData({ required String sourceAccount, required String csvContent, }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    await _db.collection('users').doc(userId).collection('raw_data').doc('${sourceAccount}_csv').set({'content': csvContent, 'lastUpdated': FieldValue.serverTimestamp()});
  }

  static Stream<Map<String, Map<String, dynamic>>> getCalculatedPortfolioStream() {
    final userId = _userId;
    if (userId == null) return Stream.value({});
    return _db.collection('users').doc(userId).collection('calculated_portfolio').snapshots().map((snapshot) {
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = doc.data();
      }
      return map;
    });
  }

  static Future<void> updateCalculatedAssetData({ required String sourceAccount, required String assetId, required Map<String, dynamic> dataToUpdate, }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    if (dataToUpdate.containsKey('currentPrice')) {
      dataToUpdate['lastPriceUpdate'] = FieldValue.serverTimestamp();
    }
    await _db.collection('users').doc(userId).collection('calculated_portfolio').doc('${sourceAccount}_$assetId').set(dataToUpdate, SetOptions(merge: true));
  }
  
  static Future<void> deleteCalculatedDataBySource(String sourceAccount) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    print("[FirestoreService] Buscando datos calculados de '$sourceAccount' para borrar...");
    final collectionRef = _db.collection('users').doc(userId).collection('calculated_portfolio');
    var query = collectionRef.where(FieldPath.documentId, isGreaterThanOrEqualTo: '${sourceAccount}_').where(FieldPath.documentId, isLessThan: '${sourceAccount}~');
    var snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;
    final WriteBatch batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print("[FirestoreService] ${snapshot.docs.length} docs de datos calculados de '$sourceAccount' eliminados.");
  }

  // --- ¡NUEVOS MÉTODOS PARA GESTIONAR WALLETS EN FIRESTORE! ---

  /// Guarda el mapa de redes y direcciones para una wallet específica.
  static Future<void> saveWalletNetworks(String walletName, Map<String, String> networks) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await _db.collection('users').doc(userId).collection('wallets').doc(walletName).set({
      'name': walletName,
      'networks': networks,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // Usamos merge por si el documento ya existe
  }

  /// Obtiene el mapa de redes y direcciones para una wallet desde Firestore.
  static Future<Map<String, String>> getWalletNetworks(String walletName) async {
    final userId = _userId;
    if (userId == null) return {};

    final docRef = _db.collection('users').doc(userId).collection('wallets').doc(walletName);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null && snapshot.data()!.containsKey('networks')) {
      final data = snapshot.data()!['networks'] as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value as String));
    }
    
    return {};
  }
}