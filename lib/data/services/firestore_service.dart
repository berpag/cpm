// lib/data/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;

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
          print("[FirestoreService] Stream recibió ${snapshot.docs.length} transacciones.");
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

  // --- ¡NUEVA FUNCIÓN! ---
  static Future<void> saveApiKey({
    required String exchangeName,
    required String apiKey,
    required String secretKey,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    // TODO: En una app de producción, estas claves DEBEN ser encriptadas antes de guardarse.
    // Por ahora, las guardamos en texto plano para fines de desarrollo.
    await _db
        .collection('users')
        .doc(userId)
        .collection('connections') // Nueva subcolección para las claves
        .doc(exchangeName.toLowerCase()) // Usamos el nombre del exchange como ID
        .set({
          'apiKey': apiKey,
          'secretKey': secretKey,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
    print("[FirestoreService] Claves para $exchangeName guardadas con éxito.");
  }
}