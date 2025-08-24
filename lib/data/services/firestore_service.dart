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
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> addTransaction(app_models.Transaction transaction) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');
    
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add(transaction.toFirestore());
  }

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
          'lastSynced': null, // Inicializamos la fecha de sincronización
        });
  }
  
  // --- ¡NUEVAS FUNCIONES! ---
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
  // -------------------------

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
}