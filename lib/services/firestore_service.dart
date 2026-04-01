import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  Future<void> saveUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Stream<UserProfile?> myProfileStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<UserProfile?>.empty();
    }
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserProfile.fromMap(doc.data()!);
    });
  }

  Stream<List<UserProfile>> discoverProfiles() {
    final currentUid = _auth.currentUser?.uid;
    return _users.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) => UserProfile.fromMap(doc.data()))
          .toList(growable: false);
    });
  }

  String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Stream<List<ChatThread>> chatThreads() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<ChatThread>>.empty();
    }

    return _chats
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                return ChatThread(
                  chatId: doc.id,
                  participants: List<String>.from(
                    data['participants'] ?? const [],
                  ),
                  lastMessage: (data['lastMessage'] ?? '') as String,
                  updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
                );
              })
              .toList(growable: false);
        });
  }

  Stream<List<ChatMessage>> chatMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('mensajes')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String toUid,
  }) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) {
      return;
    }

    final chatRef = _chats.doc(chatId);
    final msgRef = chatRef.collection('mensajes').doc();

    await _firestore.runTransaction((tx) async {
      tx.set(chatRef, {
        'participants': [fromUid, toUid],
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(msgRef, {
        'id': msgRef.id,
        'texto': text,
        'emisorId': fromUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> ensureThreadWith(String otherUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || otherUid.isEmpty) {
      return;
    }

    final chatId = chatIdFor(myUid, otherUid);
    await _chats.doc(chatId).set({
      'participants': [myUid, otherUid],
      'lastMessage': 'Chat iniciado para conoceros mejor.',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserProfile?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return UserProfile.fromMap(doc.data()!);
  }
}

class ChatThread {
  const ChatThread({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
  });

  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? updatedAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUid,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String fromUid;
  final DateTime? createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] ?? '') as String,
      text: ((map['texto'] ?? map['text']) ?? '') as String,
      fromUid: ((map['emisorId'] ?? map['fromUid']) ?? '') as String,
      createdAt: ((map['timestamp'] ?? map['createdAt']) as Timestamp?)
          ?.toDate(),
    );
  }
}
