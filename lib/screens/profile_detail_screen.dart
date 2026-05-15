import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/app_cached_network_image.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String userUid;
  final String? heroTag;

  const ProfileDetailScreen({required this.userUid, this.heroTag, super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<UserProfile?> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _fetchUserProfile();
  }

  Future<UserProfile?> _fetchUserProfile() async {
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(widget.userUid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout cargando perfil');
            },
          );
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), elevation: 0),
      body: FutureBuilder<UserProfile?>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text('Error al cargar el perfil'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.data == null) {
            return const Center(child: Text('Perfil no encontrado'));
          }

          final user = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: widget.heroTag ?? user.uid,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SizedBox(
                      height: 280,
                      child: _profileHeroImage(user.fotoPerfil),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Nombre y edad
                Center(
                  child: Text(
                    '${user.nombre}, ${user.edad}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // Ubicación
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.origen,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Bio
                if (user.bio.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sobre mí',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.bio,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Hábitos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hábitos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HabitChip(
                        icon: Icons.smoking_rooms,
                        label: user.fumador ? 'Fumador' : 'No fumador',
                      ),
                      const SizedBox(height: 8),
                      _HabitChip(
                        icon: Icons.pets,
                        label: user.mascotas
                            ? 'Tiene mascotas'
                            : 'Sin mascotas',
                      ),
                      const SizedBox(height: 8),
                      _HabitChip(
                        icon: Icons.schedule,
                        label: 'Horario: ${user.horario}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Información académica
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (user.estudios.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Estudios: ${user.estudios}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      Text(
                        user.tienePiso
                            ? 'Tiene piso: ${user.precioAlquilerPorPersona}€/mes'
                            : 'Buscando piso',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botones de acción
                ElevatedButton.icon(
                  onPressed: () {
                    // Aquí podría navegar a chat o similar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat abierto')),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Enviar mensaje'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileHeroImage(String imageUrl) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return AppCachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _HabitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HabitChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
