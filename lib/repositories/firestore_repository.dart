import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRepository {
  FirestoreRepository._internal();
  static final FirestoreRepository instance = FirestoreRepository._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return firestore.collection(path);
  }

  DocumentReference<Map<String, dynamic>> doc(
    String collectionPath,
    String id,
  ) {
    return firestore.collection(collectionPath).doc(id);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    String collectionPath,
    String id,
  ) {
    return doc(collectionPath, id).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> docSnapshots(
    String collectionPath,
    String id,
  ) {
    return doc(collectionPath, id).snapshots();
  }

  Future<void> setDoc(
    String collectionPath,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return doc(collectionPath, id).set(data, SetOptions(merge: merge));
  }

  Future<void> updateDoc(
    String collectionPath,
    String id,
    Map<String, dynamic> data,
  ) {
    return doc(collectionPath, id).update(data);
  }

  Future<void> deleteDoc(String collectionPath, String id) {
    return doc(collectionPath, id).delete();
  }
}
