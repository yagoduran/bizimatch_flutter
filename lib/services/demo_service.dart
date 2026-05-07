import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class DemoService {
  DemoService._();
  static final DemoService instance = DemoService._();

  final ValueNotifier<bool> isDemoMode = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> selectedDemoUser =
      ValueNotifier<UserProfile?>(null);
  final ValueNotifier<int> resetRevision = ValueNotifier<int>(0);

  late final List<UserProfile> demoProfiles = _buildDemoProfiles();

  late List<ChatThread> demoThreads = _buildDemoThreads();

  void enableDemo(bool enabled) {
    isDemoMode.value = enabled;
    if (enabled && selectedDemoUser.value == null && demoProfiles.isNotEmpty) {
      selectedDemoUser.value = demoProfiles[0];
    }
  }

  void selectDemoUserByUid(String uid) {
    final found = demoProfiles.firstWhere(
      (p) => p.uid == uid,
      orElse: () => demoProfiles.first,
    );
    selectedDemoUser.value = found;
  }

  void resetDemoData() {
    demoThreads = <ChatThread>[];
    resetRevision.value++;

    final selected = selectedDemoUser.value;
    if (selected != null) {
      selectedDemoUser.value = _copyWithDemoPoints(selected, 0);
    } else if (demoProfiles.isNotEmpty) {
      selectedDemoUser.value = _copyWithDemoPoints(demoProfiles.first, 0);
    }
  }

  void registerDemoChat(UserProfile user) {
    final chatId = 'demo_chat_${user.uid}';
    final exists = demoThreads.any((thread) => thread.chatId == chatId);
    if (exists) {
      return;
    }

    demoThreads = [
      ChatThread(
        chatId: chatId,
        participants: ['demo_me', user.uid],
        lastMessage: 'Chat iniciado desde la demo.',
        updatedAt: DateTime.now(),
      ),
      ...demoThreads,
    ];
  }

  UserProfile _copyWithDemoPoints(UserProfile profile, int points) {
    return UserProfile(
      uid: profile.uid,
      email: profile.email,
      nombre: profile.nombre,
      fechaNacimiento: profile.fechaNacimiento,
      genero: profile.genero,
      origen: profile.origen,
      estudios: profile.estudios,
      fumador: profile.fumador,
      mascotas: profile.mascotas,
      tienePiso: profile.tienePiso,
      precioAlquilerPorPersona: profile.precioAlquilerPorPersona,
      horario: profile.horario,
      teletrabajo: profile.teletrabajo,
      frecuenciaFiestas: profile.frecuenciaFiestas,
      nivelLimpieza: profile.nivelLimpieza,
      bio: profile.bio,
      fotoPerfil: profile.fotoPerfil,
      intereses: profile.intereses,
      lugarDeseado: profile.lugarDeseado,
      direccionZona: profile.direccionZona,
      fotosPiso: profile.fotosPiso,
      voiceBioUrl: profile.voiceBioUrl,
      karma: profile.karma,
      biziPuntos: points,
      rachaDias: 0,
      comodinRachaDisponible: true,
      semanasPerfectas: 0,
      totalResenas: profile.totalResenas,
      medallasResumen: profile.medallasResumen,
    );
  }

  static List<UserProfile> _buildDemoProfiles() {
    return [
      UserProfile(
        uid: 'demo_1',
        email: 'daniel@demo.local',
        nombre: 'Daniel Ruiz',
        fechaNacimiento: DateTime(1995, 11, 12),
        genero: 'Hombre',
        origen: 'Sevilla, España',
        estudios: 'Ingeniería informática',
        fumador: false,
        mascotas: false,
        tienePiso: true,
        precioAlquilerPorPersona: 450,
        horario: 'Noche',
        bio:
            'Ingeniero de software, limpio y responsable con los gastos del piso.',
        fotoPerfil: 'assets/images/demo_people/daniel.jpg',
        intereses: ['Tecnologia', 'Gaming', 'Deporte'],
        fotosPiso: const ['assets/images/demo_apartments/piso1.jpg'],
      ),
      UserProfile(
        uid: 'demo_2',
        email: 'lucia@demo.local',
        nombre: 'Lucia Fernandez',
        fechaNacimiento: DateTime(2000, 1, 5),
        genero: 'Mujer',
        origen: 'Bilbao, España',
        estudios: 'Master en psicologia',
        fumador: true,
        mascotas: false,
        tienePiso: true,
        precioAlquilerPorPersona: 380,
        horario: 'Manana',
        bio: 'Estudio un máster y busco compañeros tranquilos y organizados.',
        fotoPerfil: 'assets/images/demo_people/lucia.jpg',
        intereses: ['Lectura', 'Musica', 'Orden'],
        fotosPiso: const ['assets/images/demo_apartments/piso2.jpg'],
      ),
      UserProfile(
        uid: 'demo_3',
        email: 'maria@demo.local',
        nombre: 'Maria Gomez',
        fechaNacimiento: DateTime(1997, 4, 2),
        genero: 'Mujer',
        origen: 'Madrid, España',
        estudios: 'Publicidad',
        fumador: false,
        mascotas: true,
        tienePiso: false,
        precioAlquilerPorPersona: null,
        horario: 'Tarde',
        bio:
            'Profesional creativa buscando compañera/o para compartir gastos y buen rollo.',
        fotoPerfil: 'assets/images/demo_people/descarga.jpg',
        intereses: ['Cocina', 'Yoga', 'Series'],
      ),
      UserProfile(
        uid: 'demo_4',
        email: 'iker@demo.local',
        nombre: 'Iker Salazar',
        fechaNacimiento: DateTime(1999, 8, 18),
        genero: 'Hombre',
        origen: 'Donostia, EspaÃ±a',
        estudios: 'DiseÃ±o industrial',
        fumador: false,
        mascotas: true,
        tienePiso: true,
        precioAlquilerPorPersona: 520,
        horario: 'Manana',
        teletrabajo: true,
        frecuenciaFiestas: 'Baja',
        nivelLimpieza: 'Estricto',
        bio: 'Trabajo hibrido, cocino bastante y busco convivencia tranquila.',
        fotoPerfil: 'assets/images/demo_people/descarga (1).jpg',
        intereses: ['DiseÃ±o', 'CafÃ©', 'Senderismo'],
        fotosPiso: const [
          'assets/images/demo_apartments/pexels-artbovich-6077368.jpg',
          'assets/images/demo_apartments/pexels-artbovich-6180669.jpg',
        ],
      ),
      UserProfile(
        uid: 'demo_5',
        email: 'nora@demo.local',
        nombre: 'Nora Vidal',
        fechaNacimiento: DateTime(2001, 2, 9),
        genero: 'Mujer',
        origen: 'Valencia, EspaÃ±a',
        estudios: 'EnfermerÃ­a',
        fumador: false,
        mascotas: false,
        tienePiso: false,
        horario: 'Noche',
        teletrabajo: false,
        frecuenciaFiestas: 'Media',
        nivelLimpieza: 'Normal',
        bio:
            'Turnos rotativos, responsable y con muchas ganas de encontrar buen ambiente.',
        fotoPerfil: 'assets/images/demo_people/descarga (2).jpg',
        intereses: ['Salud', 'Running', 'Cine'],
      ),
      UserProfile(
        uid: 'demo_6',
        email: 'alba@demo.local',
        nombre: 'Alba Romero',
        fechaNacimiento: DateTime(1998, 6, 27),
        genero: 'Mujer',
        origen: 'Granada, EspaÃ±a',
        estudios: 'ADE',
        fumador: true,
        mascotas: true,
        tienePiso: true,
        precioAlquilerPorPersona: 410,
        horario: 'Tarde',
        teletrabajo: false,
        frecuenciaFiestas: 'Media',
        nivelLimpieza: 'Normal',
        bio:
            'Piso luminoso, compaÃ±eros sociables y normas claras desde el principio.',
        fotoPerfil: 'assets/images/demo_people/descarga (3).jpg',
        intereses: ['Viajes', 'MÃºsica', 'Tapas'],
        fotosPiso: const [
          'assets/images/demo_apartments/pexels-artbovich-6444244.jpg',
          'assets/images/demo_apartments/pexels-artbovich-6444980.jpg',
        ],
      ),
      UserProfile(
        uid: 'demo_7',
        email: 'samuel@demo.local',
        nombre: 'Samuel Ortega',
        fechaNacimiento: DateTime(1996, 12, 3),
        genero: 'Hombre',
        origen: 'Madrid, EspaÃ±a',
        estudios: 'MÃ¡ster en Datos',
        fumador: false,
        mascotas: false,
        tienePiso: false,
        horario: 'Manana',
        teletrabajo: true,
        frecuenciaFiestas: 'Baja',
        nivelLimpieza: 'Estricto',
        bio: 'Teletrabajo varios dÃ­as y valoro mucho el silencio y el orden.',
        fotoPerfil: 'assets/images/demo_people/descarga (4).jpg',
        intereses: ['Datos', 'Ajedrez', 'Gimnasio'],
      ),
      UserProfile(
        uid: 'demo_8',
        email: 'claudia@demo.local',
        nombre: 'Claudia Marin',
        fechaNacimiento: DateTime(2000, 9, 14),
        genero: 'Mujer',
        origen: 'Zaragoza, EspaÃ±a',
        estudios: 'ComunicaciÃ³n audiovisual',
        fumador: false,
        mascotas: true,
        tienePiso: true,
        precioAlquilerPorPersona: 470,
        horario: 'Tarde',
        teletrabajo: true,
        frecuenciaFiestas: 'Alta',
        nivelLimpieza: 'Relajado',
        bio:
            'Piso creativo y social cerca del centro, ideal para gente abierta.',
        fotoPerfil: 'assets/images/demo_people/descarga (5).jpg',
        intereses: ['Foto', 'Festivales', 'Perros'],
        fotosPiso: const [
          'assets/images/demo_apartments/pexels-artbovich-6480206.jpg',
          'assets/images/demo_apartments/pexels-artbovich-6580377.jpg',
        ],
      ),
      ..._buildExtraDemoPeopleProfiles(),
    ];
  }

  static List<UserProfile> _buildExtraDemoPeopleProfiles() {
    const peopleAssets = [
      'assets/images/demo_people/descarga (6).jpg',
      'assets/images/demo_people/descarga (7).jpg',
      'assets/images/demo_people/descarga (8).jpg',
      'assets/images/demo_people/descarga (9).jpg',
      'assets/images/demo_people/descarga (10).jpg',
      'assets/images/demo_people/descarga (11).jpg',
      'assets/images/demo_people/descarga (12).jpg',
      'assets/images/demo_people/descarga (13).jpg',
      'assets/images/demo_people/descarga (14).jpg',
      'assets/images/demo_people/descarga (15).jpg',
      'assets/images/demo_people/descarga (16).jpg',
      'assets/images/demo_people/descarga (17).jpg',
      'assets/images/demo_people/descarga (18).jpg',
      'assets/images/demo_people/descarga (19).jpg',
    ];
    const names = [
      'Adrian Vega',
      'Leire Castro',
      'Pablo Navarro',
      'Irene Soler',
      'Hugo Medina',
      'Marta Rivas',
      'Aitor Molina',
      'Paula Santos',
      'Gorka Prieto',
      'Elena Torres',
      'Marco Gil',
      'Nerea Lopez',
      'Joel Martin',
      'Laia Costa',
      'Ruben Arias',
    ];
    const origins = [
      'Madrid, Espana',
      'Barcelona, Espana',
      'Valencia, Espana',
      'Bilbao, Espana',
      'Sevilla, Espana',
    ];
    const studies = [
      'Marketing',
      'Ingenieria',
      'Arquitectura',
      'Psicologia',
      'Diseno UX',
    ];
    const apartmentAssets = [
      'assets/images/demo_apartments/pexels-artbovich-6580381.jpg',
      'assets/images/demo_apartments/pexels-artbovich-6890393.jpg',
      'assets/images/demo_apartments/pexels-artbovich-6899444.jpg',
      'assets/images/demo_apartments/pexels-artbovich-6933856.jpg',
      'assets/images/demo_apartments/pexels-artbovich-6970049.jpg',
      'assets/images/demo_apartments/pexels-artbovich-6970056.jpg',
      'assets/images/demo_apartments/pexels-artbovich-7019026.jpg',
      'assets/images/demo_apartments/pexels-artbovich-7031214.jpg',
      'assets/images/demo_apartments/pexels-artbovich-7040700.jpg',
      'assets/images/demo_apartments/pexels-artbovich-7511701.jpg',
    ];

    return List<UserProfile>.generate(peopleAssets.length, (index) {
      final hasHouse = index.isEven;
      final firstHousePhoto = apartmentAssets[index % apartmentAssets.length];
      final secondHousePhoto =
          apartmentAssets[(index + 1) % apartmentAssets.length];
      return UserProfile(
        uid: 'demo_${index + 9}',
        email: 'demo${index + 9}@demo.local',
        nombre: names[index],
        fechaNacimiento: DateTime(1995 + (index % 8), (index % 12) + 1, 8),
        genero: index.isEven ? 'Hombre' : 'Mujer',
        origen: origins[index % origins.length],
        estudios: studies[index % studies.length],
        fumador: index % 5 == 0,
        mascotas: index % 3 == 0,
        tienePiso: hasHouse,
        precioAlquilerPorPersona: hasHouse ? 390 + (index * 15) : null,
        horario: index % 3 == 0
            ? 'Manana'
            : index % 3 == 1
            ? 'Tarde'
            : 'Noche',
        teletrabajo: index % 2 == 0,
        frecuenciaFiestas: index % 4 == 0 ? 'Media' : 'Baja',
        nivelLimpieza: index % 3 == 0 ? 'Estricto' : 'Normal',
        bio: hasHouse
            ? 'Tengo una habitacion lista para entrar y busco convivencia facil.'
            : 'Busco piso compartido con gente responsable y buen ambiente.',
        fotoPerfil: peopleAssets[index],
        intereses: const ['Convivencia', 'Cocina', 'Planes'],
        fotosPiso: hasHouse ? [firstHousePhoto, secondHousePhoto] : const [],
      );
    });
  }

  static List<ChatThread> _buildDemoThreads() {
    final now = DateTime.now();
    return [
      ChatThread(
        chatId: 'demo_chat_demo_1',
        participants: ['demo_me', 'demo_1'],
        lastMessage: 'Hola, gracias por el like — ¿qué zona buscas?',
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      ChatThread(
        chatId: 'demo_chat_demo_2',
        participants: ['demo_me', 'demo_2'],
        lastMessage: 'Puedo mostrarte el piso este fin de semana.',
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
    ];
  }
}
