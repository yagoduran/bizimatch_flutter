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

class SwipeReward {
  const SwipeReward({
    required this.pointsEarned,
    this.streakBonusAwarded = false,
    this.streakShieldUsed = false,
    this.streakDays = 0,
  });

  final int pointsEarned;
  final bool streakBonusAwarded;
  final bool streakShieldUsed;
  final int streakDays;
}

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
    final userRef = _users.doc(profile.uid);
    final existingDoc = await userRef.get();
    final existingData = existingDoc.data() ?? const <String, dynamic>{};

    final payload = profile.toMap();
    final currentPoints = (existingData['biziPuntos'] as num?)?.toInt() ?? 0;
    final hasBioBonus = (existingData['bonusBioOtorgado'] ?? false) as bool;

    int pointsGained = 0;
    bool nextHasBioBonus = hasBioBonus;
    if (!hasBioBonus && _isBioCompleta(profile.bio)) {
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
    if (amount <= 0 || uid.trim().isEmpty) {
      return const SwipeReward(pointsEarned: 0);
    }

    final userRef = _users.doc(uid);
    int granted = amount;
    bool streakBonusAwarded = false;
    bool streakShieldUsed = false;
    int streakDays = 0;

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentPoints = (data['biziPuntos'] as num?)?.toInt() ?? 0;

      final update = <String, dynamic>{};

      final now = DateTime.now();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final dayKey = '${now.year}-$mm-$dd';
      final weekKey = _weekKeyFromDate(now);

      if (increaseDailySwipes) {
        final rawDaily = data['swipesDiarios'];
        final daily = rawDaily is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawDaily)
            : <String, dynamic>{};
        final dayCount = (daily[dayKey] as num?)?.toInt() ?? 0;
        daily[dayKey] = dayCount + 1;
        update['swipesDiarios'] = daily;

        final prevStreak = (data['rachaDias'] as num?)?.toInt() ?? 0;
        final prevDayKey = (data['rachaUltimoDia'] ?? '') as String;
        final prevWeekKey = (data['rachaComodinSemana'] ?? '') as String;
        bool shieldAvailable =
            (data['comodinRachaDisponible'] as bool?) ?? true;

        if (prevWeekKey != weekKey) {
          shieldAvailable = true;
          update['rachaComodinSemana'] = weekKey;
          update['comodinRachaDisponible'] = true;
        }

        if (dayCount == 0) {
          final daysDiff = _daysBetween(prevDayKey, dayKey);
          if (daysDiff == 2 && shieldAvailable && prevStreak > 0) {
            streakDays = prevStreak + 1;
            shieldAvailable = false;
            streakShieldUsed = true;
            update['comodinRachaDisponible'] = false;
            update['rachaComodinSemana'] = weekKey;
          } else {
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
        streakDays = (data['rachaDias'] as num?)?.toInt() ?? 0;
      }

      update['biziPuntos'] = currentPoints + granted;
      update['lastPointsGain'] = granted;
      update['lastPointsReason'] = streakShieldUsed
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
      streakDays: streakDays,
    );
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

  /// Poblar España con 50 usuarios realistas
  Future<void> poblarEspana() async {
    final batch = _firestore.batch();
    final usuarios = _generarUsuarios50();

    for (final usuario in usuarios) {
      final docRef = _users.doc();
      batch.set(docRef, {'uid': docRef.id, ...usuario});
    }

    await batch.commit();
  }

  /// Generar 50 usuarios con datos realistas
  List<Map<String, dynamic>> _generarUsuarios50() {
    final nombresMasculinos = [
      'Carlos',
      'Miguel',
      'Luis',
      'José',
      'Antonio',
      'Juan',
      'Javier',
      'Sergio',
      'Pablo',
      'Diego',
      'Francisco',
      'Andrés',
      'Ángel',
      'Roberto',
      'Ramón',
    ];
    final nombresFemeninos = [
      'María',
      'Ana',
      'Isabel',
      'Carmen',
      'Francisca',
      'Teresa',
      'Sofía',
      'Laura',
      'Gabriela',
      'Martina',
      'Catalina',
      'Valentina',
      'Lucía',
      'Marta',
      'Patricia',
    ];
    final apellidos = [
      'García',
      'López',
      'González',
      'Hernández',
      'Pérez',
      'Martínez',
      'Sánchez',
      'Díaz',
      'Ruiz',
      'Moreno',
      'Álvarez',
      'Jiménez',
      'Navarro',
      'Fernández',
      'Rodríguez',
    ];

    const ciudadesBase = <Map<String, dynamic>>[
      {'ciudad': 'Madrid', 'lat': 40.4168, 'lng': -3.7038},
      {'ciudad': 'Barcelona', 'lat': 41.3874, 'lng': 2.1686},
      {'ciudad': 'Valencia', 'lat': 39.4699, 'lng': -0.3763},
      {'ciudad': 'Sevilla', 'lat': 37.3891, 'lng': -5.9845},
      {'ciudad': 'Zaragoza', 'lat': 41.6488, 'lng': -0.8891},
      {'ciudad': 'Malaga', 'lat': 36.7213, 'lng': -4.4214},
      {'ciudad': 'Murcia', 'lat': 37.9922, 'lng': -1.1307},
      {'ciudad': 'Palma', 'lat': 39.5696, 'lng': 2.6502},
      {'ciudad': 'Las Palmas', 'lat': 28.1235, 'lng': -15.4363},
      {'ciudad': 'Bilbao', 'lat': 43.2630, 'lng': -2.9350},
      {'ciudad': 'Alicante', 'lat': 38.3452, 'lng': -0.4810},
      {'ciudad': 'Cordoba', 'lat': 37.8882, 'lng': -4.7794},
      {'ciudad': 'Valladolid', 'lat': 41.6523, 'lng': -4.7245},
      {'ciudad': 'Vigo', 'lat': 42.2406, 'lng': -8.7207},
      {'ciudad': 'Gijon', 'lat': 43.5322, 'lng': -5.6611},
    ];
    const estudios = [
      'Ingeniería',
      'Medicina',
      'Derecho',
      'Administración',
      'Turismo',
      'Marketing',
    ];
    const bios = [
      'Busco compañeros relajados para compartir piso',
      'Me encanta pasar tiempo con amigos',
      'Yoga y café por las mañanas',
      'Músico en mis ratos libres',
      'Viajes y aventuras',
      'Cinéfila de corazón',
      'Cocinero aficionado',
      'Amante del running',
      'Fotógrafo amateur',
      'Emprendedor en desarrollo',
    ];

    const fotosPortrait = [
      'https://source.unsplash.com/featured/?man,portrait,20-30',
      'https://source.unsplash.com/featured/?woman,portrait,20-30',
      'https://source.unsplash.com/featured/?person,face',
      'https://source.unsplash.com/featured/?student,portrait',
      'https://source.unsplash.com/featured/?young,face',
    ];

    const fotosRoom = [
      'https://source.unsplash.com/featured/?apartment,room',
      'https://source.unsplash.com/featured/?bedroom,modern',
      'https://source.unsplash.com/featured/?room,student',
      'https://source.unsplash.com/featured/?flat,living',
      'https://source.unsplash.com/featured/?apartment,bedroom',
    ];

    final random = math.Random();
    final usuarios = <Map<String, dynamic>>[];

    for (int i = 0; i < 50; i++) {
      final esHombre = random.nextBool();
      final nombre = esHombre
          ? nombresMasculinos[random.nextInt(nombresMasculinos.length)]
          : nombresFemeninos[random.nextInt(nombresFemeninos.length)];
      final apellido = apellidos[random.nextInt(apellidos.length)];
      final genero = esHombre ? 'Hombre' : 'Mujer';
      final edad = 20 + random.nextInt(25);
      final base = ciudadesBase[random.nextInt(ciudadesBase.length)];
      final ciudad = base['ciudad'] as String;
      final baseLat = base['lat'] as double;
      final baseLng = base['lng'] as double;
      final latitud = baseLat + (random.nextDouble() * 0.10 - 0.05);
      final longitud = baseLng + (random.nextDouble() * 0.10 - 0.05);
      final estudio = estudios[random.nextInt(estudios.length)];
      final bio = bios[random.nextInt(bios.length)];
      final horario = ['Manana', 'Tarde', 'Noche'][random.nextInt(3)];
      final teletrabajo = random.nextBool();
      final frecuenciaFiestas = ['Alta', 'Media', 'Baja'][random.nextInt(3)];
      final nivelLimpieza = [
        'Estricto',
        'Normal',
        'Relajado',
      ][random.nextInt(3)];
      final fumador = random.nextBool();
      final mascotas = random.nextBool();

      // 40% tiene piso, 60% si no tiene
      final tienePiso = random.nextDouble() < 0.4;
      final precio = tienePiso ? 350 + random.nextInt(300) : null;

      usuarios.add({
        'nombre': nombre,
        'apellido': apellido,
        'email': '$nombre.$apellido$i@bizimatch.local',
        'edad': edad,
        'genero': genero,
        'origen': '$ciudad, España',
        'lugarDeseado':
            '${(ciudadesBase[random.nextInt(ciudadesBase.length)]['ciudad'] as String)}, España',
        'fotoPerfil': fotosPortrait[random.nextInt(fotosPortrait.length)],
        'fotosPiso': tienePiso
            ? [fotosRoom[random.nextInt(fotosRoom.length)]]
            : [],
        'estudios': estudio,
        'bio': bio,
        'intereses': [
          estudios[random.nextInt(estudios.length)],
          bios[random.nextInt(bios.length)],
        ],
        'habitos': [if (fumador) 'Fumar', if (mascotas) 'Mascotas', 'Limpiar'],
        'horario': horario,
        'teletrabajo': teletrabajo,
        'frecuenciaFiestas': frecuenciaFiestas,
        'nivelLimpieza': nivelLimpieza,
        'fumador': fumador,
        'mascotas': mascotas,
        'tienePiso': tienePiso,
        'precioAlquilerPorPersona': precio,
        'direccionZona': '$ciudad, España',
        'latitud': latitud,
        'longitud': longitud,
        'coordenadas': GeoPoint(latitud, longitud),
        'verificado': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return usuarios;
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
