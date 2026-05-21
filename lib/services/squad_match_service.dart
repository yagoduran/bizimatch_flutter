import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/escuadron_model.dart';
import 'escuadron_service.dart';

class SquadMatchResult {
  const SquadMatchResult({
    required this.squadId,
    required this.houseId,
    required this.liked,
    required this.isMatch,
    this.chatId,
    this.ownerUid,
  });

  final String squadId;
  final String houseId;
  final bool liked;
  final bool isMatch;
  final String? chatId;
  final String? ownerUid;
}

class SquadMatchService {
  SquadMatchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final EscuadronService _escuadronService = EscuadronService.instance;

  CollectionReference<Map<String, dynamic>> get _squads =>
      _firestore.collection('squads');

  CollectionReference<Map<String, dynamic>> get _houses =>
      _firestore.collection('viviendas');

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  Future<SquadMatchResult> recordSquadSwipe({
    required String squadId,
    required String houseId,
    required bool liked,
  }) async {
    try {
      final squad = await _escuadronService.obtenerEscuadron(squadId);
      if (squad == null) {
        throw StateError('Squad no encontrado: $squadId');
      }

      await _squads.doc(squadId).collection('swipes').doc(houseId).set({
        'squadId': squadId,
        'houseId': houseId,
        'liked': liked,
        'memberIdsSnapshot': squad.listaMiembrosIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _houses.doc(houseId).set({
        'squadLikes.$squadId': liked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!liked) {
        return SquadMatchResult(
          squadId: squadId,
          houseId: houseId,
          liked: false,
          isMatch: false,
        );
      }

      return _evaluateMatch(
        squad: squad,
        squadId: squadId,
        houseId: houseId,
      );
    } on FirebaseException catch (e) {
      debugPrint('Squad swipe FirebaseException: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Squad swipe error: $e');
      rethrow;
    }
  }

  Future<SquadMatchResult> recordOwnerSwipeOnSquad({
    required String houseId,
    required String squadId,
    required String ownerUid,
    required bool liked,
  }) async {
    try {
      await _houses.doc(houseId).collection('squadSwipes').doc(squadId).set({
        'houseId': houseId,
        'squadId': squadId,
        'ownerUid': ownerUid,
        'liked': liked,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _houses.doc(houseId).set({
        'squadOwnerLikes.$squadId': liked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final squad = await _escuadronService.obtenerEscuadron(squadId);
      if (squad == null) {
        throw StateError('Squad no encontrado: $squadId');
      }

      if (!liked) {
        return SquadMatchResult(
          squadId: squadId,
          houseId: houseId,
          liked: false,
          isMatch: false,
          ownerUid: ownerUid,
        );
      }

      return _evaluateMatch(
        squad: squad,
        squadId: squadId,
        houseId: houseId,
        ownerUid: ownerUid,
      );
    } on FirebaseException catch (e) {
      debugPrint('Owner squad approval FirebaseException: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Owner squad approval error: $e');
      rethrow;
    }
  }

  Future<bool> hasSquadLikedHouse(String squadId, String houseId) async {
    final doc = await _squads.doc(squadId).collection('swipes').doc(houseId).get();
    return (doc.data()?['liked'] as bool?) ?? false;
  }

  Future<bool> hasOwnerApprovedSquad(String houseId, String squadId) async {
    final doc = await _houses.doc(houseId).collection('squadSwipes').doc(squadId).get();
    return (doc.data()?['liked'] as bool?) ?? false;
  }

  Stream<List<SquadMatchResult>> watchSquadMatches(String squadId) {
    return _squads
        .doc(squadId)
        .collection('matches')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return SquadMatchResult(
              squadId: (data['squadId'] ?? squadId) as String,
              houseId: (data['houseId'] ?? doc.id) as String,
              liked: true,
              isMatch: true,
              chatId: data['chatId'] as String?,
              ownerUid: data['ownerUid'] as String?,
            );
          }).toList(growable: false),
        );
  }

  Future<SquadMatchResult> _evaluateMatch({
    required Escuadron squad,
    required String squadId,
    required String houseId,
    String? ownerUid,
  }) async {
    final houseDoc = await _houses.doc(houseId).get();
    if (!houseDoc.exists) {
      throw StateError('Housing no encontrado: $houseId');
    }

    final houseData = houseDoc.data() ?? <String, dynamic>{};
    final resolvedOwnerUid = ownerUid ?? (houseData['propietarioUid'] as String? ?? '');
    if (resolvedOwnerUid.isEmpty) {
      throw StateError('No se pudo resolver el propietario de la vivienda.');
    }

    final squadLiked = await hasSquadLikedHouse(squadId, houseId);
    final ownerApproved = await hasOwnerApprovedSquad(houseId, squadId);
    if (!squadLiked || !ownerApproved) {
      return SquadMatchResult(
        squadId: squadId,
        houseId: houseId,
        liked: squadLiked,
        isMatch: false,
        ownerUid: resolvedOwnerUid,
      );
    }

    final chatId = await _ensureGroupChat(
      squad: squad,
      squadId: squadId,
      houseId: houseId,
      ownerUid: resolvedOwnerUid,
    );

    await _squads.doc(squadId).collection('matches').doc(houseId).set({
      'squadId': squadId,
      'houseId': houseId,
      'ownerUid': resolvedOwnerUid,
      'chatId': chatId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _houses.doc(houseId).set({
      'squadMatches.$squadId': true,
      'squadMatchChatIds.$squadId': chatId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return SquadMatchResult(
      squadId: squadId,
      houseId: houseId,
      liked: true,
      isMatch: true,
      chatId: chatId,
      ownerUid: resolvedOwnerUid,
    );
  }

  Future<String> _ensureGroupChat({
    required Escuadron squad,
    required String squadId,
    required String houseId,
    required String ownerUid,
  }) async {
    final participants = <String>{ownerUid, ...squad.listaMiembrosIds}.toList()
      ..sort();
    final chatId = 'squad_${squadId}_house_${houseId}_owner_${ownerUid}';
    final chatRef = _chats.doc(chatId);

    await chatRef.set({
      'chatType': 'squad_house',
      'squadId': squadId,
      'houseId': houseId,
      'ownerUid': ownerUid,
      'participants': participants,
      'lastMessage': 'Match de escuadrón creado.',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isGroupChat': true,
    }, SetOptions(merge: true));

    await chatRef.collection('mensajes').add({
      'id': 'system_${DateTime.now().millisecondsSinceEpoch}',
      'texto': '¡Habéis hecho match con esta vivienda! Ya podéis coordinaros aquí.',
      'emisorId': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
    });

    return chatId;
  }
}
