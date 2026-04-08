import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

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

  CollectionReference<Map<String, dynamic>> get _interacciones =>
      _firestore.collection('interacciones');

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

  /// Guardar un swipe (like o dislike) en la colección de interacciones
  Future<void> guardarSwipe({
    required String toUid,
    required String tipo, // 'like' o 'dislike'
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final interaccionId =
        '${myUid}_${toUid}_${tipo}_${DateTime.now().millisecondsSinceEpoch}';
    await _interacciones.doc(interaccionId).set({
      'fromId': myUid,
      'toId': toUid,
      'tipo': tipo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Si es un like, verificar si hay match
    if (tipo == 'like') {
      await _buscarYCrearMatch(myUid, toUid);
    }
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
