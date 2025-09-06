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
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => app_models.Transaction.fromFirestore(doc.data()))
              .toList();
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

  // --- ¡NUEVA Y ROBUSTA FUNCIÓN DE BORRADO! ---
  static Future<void> deleteAllUserData() async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado.');

    final collectionRef = _db.collection('users').doc(userId).collection('transactions');
    
    // Firestore recomienda borrar en lotes de 500 para evitar problemas de memoria.
    var snapshot = await collectionRef.limit(500).get();
    
    while(snapshot.docs.isNotEmpty) {
      final WriteBatch batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("[FirestoreService] Lote de ${snapshot.docs.length} transacciones eliminadas.");
      
      // Obtenemos el siguiente lote
      snapshot = await collectionRef.limit(500).get();
    }

    print("[FirestoreService] Todas las transacciones del usuario $userId han sido eliminadas.");
    
    // Opcional: Si también quieres eliminar el documento del usuario (el "padre") después de borrar la subcolección.
    // await _db.collection('users').doc(userId).delete();
  }
}