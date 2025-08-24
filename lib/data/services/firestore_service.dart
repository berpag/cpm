// lib/data/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;

class ApiConnection {
  final String exchangeName;
  final String apiKey;
  
  ApiConnection({required this.exchangeName, required this.apiKey});
  
  factory ApiConnection.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ApiConnection(
      exchangeName: doc.id,
      apiKey: data['apiKey'],
    );
  }
}

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance; // Añadido para consistencia
  static String? get _userId => _auth.currentUser?.uid;

  static Future<void> addTransaction(app_models.Transaction transaction) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add(transaction.toFirestore());
  }

  // --- ¡FUNCIÓN 'addTransactionsBatch' MEJORADA Y A PRUEBA DE LÍMITES! ---
  static Future<void> addTransactionsBatch(List<app_models.Transaction> transactions) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    final transactionsCollection = _db.collection('users').doc(userId).collection('transactions');

    // Consultamos las transacciones existentes para evitar duplicados
    final existingSnapshot = await transactionsCollection.get();
    final existingTradeIds = existingSnapshot.docs.map((doc) => doc.data()['exchangeTradeId']).toSet();

    final List<app_models.Transaction> newTransactions = [];
    for (final transaction in transactions) {
      if (transaction.exchangeTradeId != null && !existingTradeIds.contains(transaction.exchangeTradeId)) {
        newTransactions.add(transaction);
        existingTradeIds.add(transaction.exchangeTradeId!); // Prevenimos duplicados en el mismo CSV
      }
    }

    if (newTransactions.isEmpty) {
      print("[Firestore] No hay transacciones nuevas para añadir.");
      return;
    }

    print("[Firestore] Se encontraron ${newTransactions.length} transacciones nuevas. Guardando en lotes...");

    // Dividimos la escritura en fragmentos de 400 para estar seguros bajo el límite de 500
    const chunkSize = 400;
    for (int i = 0; i < newTransactions.length; i += chunkSize) {
      final batch = _db.batch();
      
      final end = (i + chunkSize < newTransactions.length) ? i + chunkSize : newTransactions.length;
      final chunk = newTransactions.sublist(i, end);

      print("[Firestore] Procesando lote ${i/chunkSize + 1}: ${chunk.length} transacciones.");

      for (final transaction in chunk) {
        final docRef = transactionsCollection.doc();
        batch.set(docRef, transaction.toFirestore());
      }
      
      await batch.commit();
    }
    print("[Firestore] Todos los lotes se han guardado con éxito.");
  }
  // --- FIN DEL NUEVO MÉTODO ---


  static Stream<List<app_models.Transaction>> getTransactionsStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }
    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => app_models.Transaction.fromFirestore(doc.data()))
              .toList();
        });
  }

  static Future<List<app_models.Transaction>> getTransactions() async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .get();

    return snapshot.docs
        .map((doc) => app_models.Transaction.fromFirestore(doc.data()))
        .toList();
  }

  static Future<void> saveApiKey({
    required String exchangeName,
    required String apiKey,
    required String secretKey,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await _db
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(exchangeName.toLowerCase())
        .set({
          'apiKey': apiKey,
          'secretKey': secretKey,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastSynced': null,
        });
  }
  
  static Future<void> updateLastSynced(String exchangeName) async {
    final userId = _userId;
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(exchangeName.toLowerCase())
        .update({'lastSynced': FieldValue.serverTimestamp()});
  }

  static Future<DateTime?> getLastSynced(String exchangeName) async {
    final userId = _userId;
    if (userId == null) return null;
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(exchangeName.toLowerCase())
        .get();
    if (doc.exists && doc.data()!.containsKey('lastSynced')) {
      final timestamp = doc.data()!['lastSynced'] as Timestamp?;
      return timestamp?.toDate();
    }
    return null;
  }

  static Future<List<ApiConnection>> getConnections() async {
    final userId = _userId;
    if (userId == null) return [];
    final snapshot = await _db.collection('users').doc(userId).collection('connections').get();
    return snapshot.docs.map((doc) => ApiConnection.fromFirestore(doc)).toList();
  }
  
  static Future<String?> getSecretKeyFor(String exchangeName) async {
    final userId = _userId;
    if (userId == null) return null;
    final doc = await _db.collection('users').doc(userId).collection('connections').doc(exchangeName.toLowerCase()).get();
    return doc.data()?['secretKey'];
  }
  static Future<void> deleteConnection(String exchangeName) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    await _db
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(exchangeName.toLowerCase())
        .delete();
  }
}