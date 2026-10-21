import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  /// Test connection to Firestore
  Future<bool> testConnection() async {
    try {
      await _firestore.collection('_connection_test').limit(1).get();
      return true;
    } catch (e) {
      // If error is permission-denied or network, Firebase is reached
      return false;
    }
  }

  /// Get reference to a collection
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  /// Add a new item with custom timestamp-based document ID
  Future<DocumentReference<Map<String, dynamic>>> addItem({
    required String collectionName,
    required Map<String, dynamic> data,
    String? idPrefix,
  }) async {
    final prefix = idPrefix ??
        (collectionName.length >= 2 ? collectionName.substring(0, 2).toUpperCase() : 'DOC');
    final docId = '$prefix${DateTime.now().millisecondsSinceEpoch}';
    final docRef = _firestore.collection(collectionName).doc(docId);
    await docRef.set({
      'ID': docId,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef;
  }

  /// Example: Stream collection data in real-time
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(String collectionName) {
    return _firestore.collection(collectionName).snapshots();
  }
}
