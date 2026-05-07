import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class DemoService {
  DemoService._();
  static final DemoService instance = DemoService._();

  final ValueNotifier<bool> isDemoMode = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> selectedDemoUser = ValueNotifier<UserProfile?>(null);

  late final List<UserProfile> demoProfiles = _buildDemoProfiles();

  late final List<ChatThread> demoThreads = _buildDemoThreads();

  void enableDemo(bool enabled) {
    isDemoMode.value = enabled;
    if (enabled && selectedDemoUser.value == null && demoProfiles.isNotEmpty) {
      selectedDemoUser.value = demoProfiles[0];
    }
  }

  void selectDemoUserByUid(String uid) {
    final found = demoProfiles.firstWhere((p) => p.uid == uid, orElse: () => demoProfiles.first);
    selectedDemoUser.value = found;
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
        bio: 'Ingeniero de software, limpio y responsable con los gastos del piso.',
        fotoPerfil: 'assets/images/demo_people/daniel.jpg',
        intereses: ['Tecnologia', 'Gaming', 'Deporte'],
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
        bio: 'Profesional creativa buscando compañera/o para compartir gastos y buen rollo.',
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
