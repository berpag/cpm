// lib/data/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/config/constants.dart'; // Importamos las constantes para la lista por defecto

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // --- NUEVA FUNCIÓN PARA OBTENER FIATS ---
  /// Obtiene un Stream con la lista de monedas fiat del usuario.
  /// Si el usuario no tiene una lista personalizada, crea una con los valores por defecto.
  static Stream<Set<String>> getFiatListStream() {
    final userId = _userId;
    if (userId == null) return Stream.value({});

    final docRef = _db.collection('users').doc(userId).collection('config').doc('fiat_currencies');

    return docRef.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) {
        // Si el documento no existe, lo creamos con la lista por defecto
        await docRef.set({'tickers': kFiatTickers.toList()});
        return kFiatTickers;
      }
      final data = snapshot.data();
      // Firestore devuelve una List<dynamic>, la convertimos a Set<String>
      final tickers = List<String>.from(data?['tickers'] ?? []);
      return tickers.toSet();
    });
  }

  // --- NUEVA FUNCIÓN PARA ACTUALIZAR FIATS ---
  /// Actualiza la lista de monedas fiat del usuario en Firestore.
  static Future<void> updateFiatList(Set<String> newFiatList) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    final docRef = _db.collection('users').doc(userId).collection('config').doc('fiat_currencies');
    await docRef.set({'tickers': newFiatList.toList()});
  }

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

  static Future<void> updateCalculatedAssetData({
    required String sourceAccount,
    required String assetId,
    required Map<String, dynamic> dataToUpdate,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    // --- ¡NUEVA LÓGICA! ---
    // Si en los datos a actualizar viene un 'currentPrice', añadimos también
    // un timestamp para saber cuándo se actualizó por última vez.
    if (dataToUpdate.containsKey('currentPrice')) {
      dataToUpdate['lastPriceUpdate'] = FieldValue.serverTimestamp();
    }
    // --- FIN DE LA NUEVA LÓGICA ---

    await _db.collection('users')
        .doc(userId)
        .collection('calculated_portfolio')
        .doc('${sourceAccount}_$assetId')
        .set(dataToUpdate, SetOptions(merge: true)); // Usamos merge para no borrar otros campos
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
}