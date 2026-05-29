import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import '../models/user_profile.dart';

const List<String> kTiposMedalla = <String>[
  'Limpieza',
  'Respeto',
  'Cocina',
  'Silencio',
];

/// SwipeReward: erantzun egokia swipe-ek emandako sari-informazioa gordetzeko.
///
/// Zer egiten duen:
/// - Swipe edo ekintza baten ondorioz eman diren puntu eta bonus-en xehetasunak encapsulatzen ditu.
/// Parametro nagusiak: `pointsEarned`, `streakBonusAwarded`, `perfectWeekAwarded`.
class SwipeReward {
  const SwipeReward({
    required this.pointsEarned,
    this.streakBonusAwarded = false,
    this.streakShieldUsed = false,
    this.perfectWeekAwarded = false,
    this.streakDays = 0,
    this.perfectWeeks = 0,
  });

  final int pointsEarned;
  final bool streakBonusAwarded;
  final bool streakShieldUsed;
  final bool perfectWeekAwarded;
  final int streakDays;
  final int perfectWeeks;
}

/// FirestoreService: aplikazioaren Firestore interakzio guztiak kudeatzen ditu.
///
/// Zer egiten duen:
/// - `usuarios`, `chats` eta `interacciones` bezalako kolekzioekin irakurtzen eta idazten du.
/// - Puntuazio mekanikak, match-acak, txat mezuak eta erabiltzaileen erregistro laguntzak egiten ditu.
///
/// Oharrak: Erabiltzen ditu `FirebaseFirestore` eta `FirebaseAuth` objektuak.
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

  CollectionReference<Map<String, dynamic>> get _interacciones =>
      _firestore.collection('interacciones');

  Future<int> saveUserProfile(UserProfile profile) async {
    /// Erabiltzaile profila gordetzen du eta bio osatuagatik bonus puntuak aplikatzen ditu.
    ///
    /// Parametroak:
    /// - `profile`: `UserProfile` objektua, Firestore-era sinkronizatzeko.
    /// Itzulera: zerbitzuak eman dituen puntu gehikuntza (int).
    final userRef = _users.doc(profile.uid);
    final existingDoc = await userRef.get();
    final existingData = existingDoc.data() ?? const <String, dynamic>{};

    final payload = profile.toMap();
    final currentPoints = (existingData['biziPuntos'] as num?)?.toInt() ?? 0;
    final hasBioBonus = (existingData['bonusBioOtorgado'] ?? false) as bool;

    int pointsGained = 0;
    bool nextHasBioBonus = hasBioBonus;
    if (!hasBioBonus && _isBioCompleta(profile.bio)) {
      // Bio osatua detektatu dugu; behin bakarrik ematen den bio-bonus-a aplikatu.
      pointsGained += 50;
      nextHasBioBonus = true;
      payload['lastPointsReason'] = 'bio';
      payload['lastPointsGain'] = 50;
      payload['lastPointsAt'] = FieldValue.serverTimestamp();
    }

    payload['bonusBioOtorgado'] = nextHasBioBonus;
    payload['biziPuntos'] = currentPoints + pointsGained;

    await userRef.set(payload, SetOptions(merge: true));
    return pointsGained;
  }

  bool _isBioCompleta(String bio) {
    final value = bio.trim();
    if (value.length < 20) {
      return false;
    }
    const genericDefaults = <String>{
      'Sin bio por ahora.',
      'Buscando compañeros de piso compatibles para convivir bien.',
    };
    return !genericDefaults.contains(value);
  }

  Future<SwipeReward> _addPoints(
    String uid,
    int amount, {
    required String reason,
    bool increaseDailySwipes = false,
  }) async {
    /// Puntuazioak gehitzen ditu erabiltzaileari, transakzio seguru baten barruan.
    ///
    /// Parametroak:
    /// - `uid`: puntu gehitu beharreko erabiltzailearen id.
    /// - `amount`: oinarrizko puntuen kopurua.
    /// - `reason`: zergatia, `lastPointsReason`-entzako.
    /// - `increaseDailySwipes`: eguneroko swipe kopurua eguneratu behar den.
    /// Itzulera: `SwipeReward` objektua, emandako informaziorekin.
    if (amount <= 0 || uid.trim().isEmpty) {
      return const SwipeReward(pointsEarned: 0);
    }

    final userRef = _users.doc(uid);
    int granted = amount;
    bool streakBonusAwarded = false;
    bool streakShieldUsed = false;
    bool perfectWeekAwarded = false;
    int streakDays = 0;
    int perfectWeeks = 0;

    // Transakzio bat egiten dugu: eguneraketa atomikoa da, datu oldarkorrei aurre egiteko.
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentPoints = (data['biziPuntos'] as num?)?.toInt() ?? 0;

      final update = <String, dynamic>{};

      // Eguneroko eta aste-oinarriko kalkuluetarako gaurko eguna eta aste-teklaren eraikitzea.
      final now = DateTime.now();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final dayKey = '${now.year}-$mm-$dd';
      final weekKey = _weekKeyFromDate(now);

      if (increaseDailySwipes) {
        // Egungo eguneroko swipes kopurua eguneratu map batean.
        final rawDaily = data['swipesDiarios'];
        final daily = rawDaily is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawDaily)
            : <String, dynamic>{};
        final dayCount = (daily[dayKey] as num?)?.toInt() ?? 0;
        daily[dayKey] = dayCount + 1;
        update['swipesDiarios'] = daily;

        // Racha eta laguntza (shield) egoerak berreskuratu.
        final prevStreak = (data['rachaDias'] as num?)?.toInt() ?? 0;
        final prevDayKey = (data['rachaUltimoDia'] ?? '') as String;
        final prevWeekKey = (data['rachaComodinSemana'] ?? '') as String;
        final prevPerfectWeeks =
            (data['semanasPerfectas'] as num?)?.toInt() ?? 0;
        perfectWeeks = prevPerfectWeeks;
        bool shieldAvailable = (data['comodinRachaDisponible'] as bool?) ?? true;

        // Aste berria hasten bada, aurreko asteko aktibitatearen arabera sari bereziak aplikatu.
        if (prevWeekKey != weekKey) {
          if (prevWeekKey.isNotEmpty) {
            final activeDaysPrevWeek = _countActiveDaysForWeek(
              daily,
              prevWeekKey,
            );
            if (activeDaysPrevWeek >= 5 && shieldAvailable) {
              const prestigeBonus = 80;
              granted += prestigeBonus;
              perfectWeekAwarded = true;
              perfectWeeks = prevPerfectWeeks + 1;
              update['semanasPerfectas'] = perfectWeeks;
            }
          }

          // Aste berrirako shield aukera berrezarri eta aste-key eguneratu.
          shieldAvailable = true;
          update['rachaComodinSemana'] = weekKey;
          update['comodinRachaDisponible'] = true;
        }

        if (dayCount == 0) {
          // Egun egunerako lehen swipe-a bada, racha logika aplikatu.
          final daysDiff = _daysBetween(prevDayKey, dayKey);
          if (daysDiff == 2 && shieldAvailable && prevStreak > 0) {
            // Komodin erabiliz racha jarraitu behar den egoera.
            streakDays = prevStreak + 1;
            shieldAvailable = false;
            streakShieldUsed = true;
            update['comodinRachaDisponible'] = false;
            update['rachaComodinSemana'] = weekKey;
          } else {
            // Racha normalaren kalkulua (jarraikortasun egiaztaketa).
            streakDays = _calcularSiguienteRacha(
              prevDayKey,
              dayKey,
              prevStreak,
            );
            update['comodinRachaDisponible'] = shieldAvailable;
            update['rachaComodinSemana'] = weekKey;
          }

          final streakBonus = 5 * streakDays.clamp(1, 7);
          granted += streakBonus;
          streakBonusAwarded = streakBonus > 0;
          update['rachaDias'] = streakDays;
          update['rachaUltimoDia'] = dayKey;
        } else {
          streakDays = prevStreak;
        }
      } else {
        // Swipes eguneratzeko beharrik ez badago, racha datuak datutik hartu.
        streakDays = (data['rachaDias'] as num?)?.toInt() ?? 0;
      }

      // Puntu eguneraketak eta azken puntuaren metadatuak prestatu.
      update['biziPuntos'] = currentPoints + granted;
      update['lastPointsGain'] = granted;
      update['lastPointsReason'] = perfectWeekAwarded
          ? 'perfect_week'
          : streakShieldUsed
          ? 'swipe_streak_shield'
          : streakBonusAwarded
          ? 'swipe_streak'
          : reason;
      update['lastPointsAt'] = FieldValue.serverTimestamp();
      update['updatedAt'] = FieldValue.serverTimestamp();

      tx.set(userRef, update, SetOptions(merge: true));
    });

    return SwipeReward(
      pointsEarned: granted,
      streakBonusAwarded: streakBonusAwarded,
      streakShieldUsed: streakShieldUsed,
      perfectWeekAwarded: perfectWeekAwarded,
      streakDays: streakDays,
      perfectWeeks: perfectWeeks,
    );
  }

  int _countActiveDaysForWeek(Map<String, dynamic> daily, String weekKey) {
    int count = 0;
    for (final entry in daily.entries) {
      final dayKey = entry.key;
      final swipes = (entry.value as num?)?.toInt() ?? 0;
      if (swipes <= 0) {
        continue;
      }
      final dayWeek = _weekKeyFromDayKey(dayKey);
      if (dayWeek == weekKey) {
        count += 1;
      }
    }
    return count;
  }

  String _weekKeyFromDayKey(String dayKey) {
    final date = DateTime.tryParse(dayKey);
    if (date == null) {
      return '';
    }
    return _weekKeyFromDate(date);
  }

  int _daysBetween(String fromKey, String toKey) {
    final from = DateTime.tryParse(fromKey);
    final to = DateTime.tryParse(toKey);
    if (from == null || to == null) {
      return 9999;
    }
    return to.difference(from).inDays;
  }

  String _weekKeyFromDate(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    final week = ((dayOfYear - 1) ~/ 7) + 1;
    return '${date.year}-W$week';
  }

  int _calcularSiguienteRacha(
    String prevDayKey,
    String currentDayKey,
    int prevStreak,
  ) {
    final prevDate = DateTime.tryParse(prevDayKey);
    final currentDate = DateTime.tryParse(currentDayKey);
    if (prevDate == null || currentDate == null) {
      return 1;
    }
    final daysDiff = currentDate.difference(prevDate).inDays;
    if (daysDiff == 1) {
      return prevStreak + 1;
    }
    if (daysDiff <= 0) {
      return prevStreak == 0 ? 1 : prevStreak;
    }
    return 1;
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
    if (currentUid == null) {
      return const Stream<List<UserProfile>>.empty();
    }

    return _users.snapshots().asyncMap((snapshot) async {
      // Obtener IDs de usuarios ya interactuados
      final interaccionados = await obtenerInteraccionados();
      final bloqueados = await obtenerBloqueados();

      return snapshot.docs
          .where(
            (doc) =>
                doc.id != currentUid &&
                !interaccionados.contains(doc.id) &&
                !bloqueados.contains(doc.id),
          )
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
        .asyncMap((snapshot) async {
          final bloqueados = await obtenerBloqueados();

          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                final participants = List<String>.from(
                  data['participants'] ?? const <String>[],
                );
                final otherUid = participants.firstWhere(
                  (id) => id != uid,
                  orElse: () => '',
                );
                return otherUid.isEmpty || !bloqueados.contains(otherUid);
              })
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

  Future<Set<String>> obtenerBloqueados() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return <String>{};

    final doc = await _users.doc(myUid).get();
    final data = doc.data();
    if (data == null) {
      return <String>{};
    }

    return List<String>.from(data['bloqueados'] ?? const <String>[]).toSet();
  }

  Future<void> bloquearUsuario(String bloqueadoUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || bloqueadoUid.trim().isEmpty) {
      return;
    }

    await _users.doc(myUid).set({
      'bloqueados': FieldValue.arrayUnion(<String>[bloqueadoUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reportarUsuario({
    required String reportadoUid,
    required String motivo,
    String? chatId,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || reportadoUid.trim().isEmpty || motivo.trim().isEmpty) {
      return;
    }

    await _firestore.collection('reportes').add({
      'reporterId': myUid,
      'reportadoUid': reportadoUid,
      'motivo': motivo,
      'chatId': chatId,
      'timestamp': FieldValue.serverTimestamp(),
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

  Stream<List<UserProfile>> myMatchedUsersStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      return const Stream<List<UserProfile>>.empty();
    }

    return _chats
        .where('participants', arrayContains: myUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final otherIds = <String>{};
          for (final doc in snapshot.docs) {
            final participants = List<String>.from(
              doc.data()['participants'] ?? const <String>[],
            );
            final otherId = participants.firstWhere(
              (id) => id != myUid,
              orElse: () => '',
            );
            if (otherId.isNotEmpty) {
              otherIds.add(otherId);
            }
          }

          if (otherIds.isEmpty) {
            return const <UserProfile>[];
          }

          final users = await Future.wait(
            otherIds.map((uid) async => getUserById(uid)),
          );

          return users.whereType<UserProfile>().toList(growable: false);
        });
  }

  Future<bool> hasMatchWithUser(String otherUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || otherUid.trim().isEmpty) {
      return false;
    }

    final chatId = chatIdFor(myUid, otherUid);
    final chat = await _chats.doc(chatId).get();
    return chat.exists;
  }

  Stream<List<UserReview>> reviewsForUser(String uid) {
    if (uid.trim().isEmpty) {
      return const Stream<List<UserReview>>.empty();
    }

    return _users
        .doc(uid)
        .collection('resenas')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserReview.fromDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> dejarResena({
    required String targetUid,
    required String texto,
    required String tipoMedalla,
  }) async {
    final autorId = _auth.currentUser?.uid;
    if (autorId == null ||
        targetUid.trim().isEmpty ||
        targetUid == autorId ||
        texto.trim().isEmpty) {
      return;
    }

    if (!kTiposMedalla.contains(tipoMedalla)) {
      throw ArgumentError('Tipo de medalla no soportado');
    }

    final hasMatch = await hasMatchWithUser(targetUid);
    if (!hasMatch) {
      throw StateError('No existe match previo para dejar reseña.');
    }

    await _users.doc(targetUid).collection('resenas').add({
      'autorId': autorId,
      'texto': texto.trim(),
      'tipoMedalla': tipoMedalla,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _recalcularKarma(targetUid);
    await _addPoints(targetUid, 100, reason: 'karma_medal');
  }

  Future<void> _recalcularKarma(String targetUid) async {
    final reviews = await _users
        .doc(targetUid)
        .collection('resenas')
        .orderBy('createdAt', descending: false)
        .get();

    final total = reviews.docs.length;
    if (total == 0) {
      await _users.doc(targetUid).set({
        'karma': 0,
        'totalResenas': 0,
        'medallasResumen': <String, int>{},
      }, SetOptions(merge: true));
      return;
    }

    const medalWeights = <String, double>{
      'Limpieza': 1.10,
      'Respeto': 1.25,
      'Cocina': 1.00,
      'Silencio': 1.15,
    };

    double weightSum = 0;
    final medallasResumen = <String, int>{};

    for (final doc in reviews.docs) {
      final tipo = (doc.data()['tipoMedalla'] ?? '') as String;
      if (tipo.isEmpty) {
        continue;
      }
      medallasResumen[tipo] = (medallasResumen[tipo] ?? 0) + 1;
      weightSum += medalWeights[tipo] ?? 1;
    }

    final weightedAverage = weightSum / total;
    final qualityScore = (weightedAverage / 1.25) * 70;
    final volumeScore = (math.min(total, 20) / 20) * 30;
    final karma = (qualityScore + volumeScore).clamp(0, 100).toDouble();

    await _users.doc(targetUid).set({
      'karma': karma,
      'totalResenas': total,
      'medallasResumen': medallasResumen,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Guardar un swipe (like o dislike) en la colección de interacciones
  Future<SwipeReward> guardarSwipe({
    required String toUid,
    required String tipo, // 'like' o 'dislike'
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      return const SwipeReward(pointsEarned: 0);
    }

    final interaccionId =
        '${myUid}_${toUid}_${tipo}_${DateTime.now().millisecondsSinceEpoch}';
    await _interacciones.doc(interaccionId).set({
      'fromId': myUid,
      'toId': toUid,
      'tipo': tipo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final gained = await _addPoints(
      myUid,
      10,
      reason: 'swipe_explore',
      increaseDailySwipes: true,
    );

    // Si es un like, verificar si hay match
    if (tipo == 'like') {
      await _buscarYCrearMatch(myUid, toUid);
    }

    return gained;
  }

  /// Buscar si el otro usuario ya me dio like (match mutuo)
  Future<void> _buscarYCrearMatch(String myUid, String otroUid) async {
    final querySnapshot = await _interacciones
        .where('fromId', isEqualTo: otroUid)
        .where('toId', isEqualTo: myUid)
        .where('tipo', isEqualTo: 'like')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Hay like mutuo - crear chat automáticamente
      await ensureThreadWith(otroUid);
    }
  }

  /// Obtener IDs de usuarios ya interactuados
  Future<Set<String>> obtenerInteraccionados() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return {};

    final snapshot = await _interacciones
        .where('fromId', isEqualTo: myUid)
        .get();

    return snapshot.docs.map((doc) => (doc['toId'] ?? '') as String).toSet();
  }

  /// Obtener likes no leídos (personas que me dieron like)
  Stream<List<String>> obtenerLikesNoLeidos() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream<List<String>>.empty();

    return _interacciones
        .where('toId', isEqualTo: myUid)
        .where('tipo', isEqualTo: 'like')
        .snapshots()
        .asyncMap((snapshot) async {
          final fromIds = <String>{};
          for (final doc in snapshot.docs) {
            final fromId = (doc['fromId'] ?? '') as String;
            // Verificar que yo aún no haya interactuado con esta persona
            final miInteraccion = await _interacciones
                .where('fromId', isEqualTo: myUid)
                .where('toId', isEqualTo: fromId)
                .limit(1)
                .get();
            if (miInteraccion.docs.isEmpty) {
              fromIds.add(fromId);
            }
          }
          return fromIds.toList();
        });
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
