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

  // --- ¡FUNCIÓN AÑADIDA! ---
  static Stream<List<app_models.Transaction>> getTransactionsStream() {
    final userId = _userId;
    if (userId == null) {
      // Si no hay usuario, devolvemos un stream vacío.
      return Stream.value([]);
    }

    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots() // ¡La magia! 'snapshots()' devuelve un Stream.
        .map((snapshot) {
          // Cada vez que hay un cambio en la base de datos, esta función se ejecuta.
          print("[FirestoreService] Stream recibió ${snapshot.docs.length} transacciones.");
          return snapshot.docs
              .map((doc) => app_models.Transaction.fromFirestore(doc.data()))
              .toList();
        });
  }
  // --- ¡NUEVA FUNCIÓN QUE FALTABA! ---
  // Obtiene las transacciones UNA SOLA VEZ (devuelve un Future)
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
}