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
        fotoPerfil: 'assets/images/demo_people/maria.jpg',
        intereses: ['Cocina', 'Yoga', 'Series'],
      ),
    ];
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
