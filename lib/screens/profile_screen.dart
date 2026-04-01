import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  Future<void> _pickProfilePhoto(UserProfile profile) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) {
      return;
    }

    final updated = UserProfile(
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
      bio: profile.bio,
      fotoPerfil: image.path,
      intereses: profile.intereses,
    );
    await _firestore.saveUserProfile(updated);
  }

  Future<void> _editarPerfil(UserProfile profile) async {
    final nombreCtrl = TextEditingController(text: profile.nombre);
    final origenCtrl = TextEditingController(text: profile.origen);
    final estudiosCtrl = TextEditingController(text: profile.estudios);
    final bioCtrl = TextEditingController(text: profile.bio);
    final precioCtrl = TextEditingController(
      text: profile.precioAlquilerPorPersona?.toStringAsFixed(0) ?? '',
    );
    String horario = profile.horario;
    bool fumador = profile.fumador;
    bool mascotas = profile.mascotas;
    bool tienePiso = profile.tienePiso;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE9E3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Editar perfil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: origenCtrl,
                      decoration: const InputDecoration(labelText: 'Origen'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: estudiosCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Que estudias',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: horario,
                      decoration: const InputDecoration(labelText: 'Horario'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Manana',
                          child: Text('Manana'),
                        ),
                        DropdownMenuItem(value: 'Tarde', child: Text('Tarde')),
                        DropdownMenuItem(value: 'Noche', child: Text('Noche')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => horario = value);
                        }
                      },
                    ),
                    SwitchListTile(
                      value: fumador,
                      activeThumbColor: AppTheme.primary,
                      title: const Text('Fumador/a'),
                      onChanged: (value) =>
                          setModalState(() => fumador = value),
                    ),
                    SwitchListTile(
                      value: mascotas,
                      activeThumbColor: AppTheme.primary,
                      title: const Text('Mascotas'),
                      onChanged: (value) =>
                          setModalState(() => mascotas = value),
                    ),
                    SwitchListTile(
                      value: tienePiso,
                      activeThumbColor: AppTheme.primary,
                      title: const Text('Tengo piso ya'),
                      onChanged: (value) {
                        setModalState(() {
                          tienePiso = value;
                          if (!tienePiso) {
                            precioCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (tienePiso) ...[
                      TextField(
                        controller: precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio alquiler por persona (EUR/mes)',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        setModalState(() {
                          bioCtrl.text = _generarBioIA(
                            nombreCtrl.text.trim(),
                            horario,
                            fumador,
                            mascotas,
                          );
                        });
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generar Bio con IA'),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        int? precio;
                        if (tienePiso) {
                          precio = int.tryParse(
                            precioCtrl.text.trim().replaceAll(',', '.'),
                          );
                          if (precio == null || precio <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Introduce un precio valido mayor que 0.',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        final updated = UserProfile(
                          uid: profile.uid,
                          email: profile.email,
                          nombre: nombreCtrl.text.trim().isEmpty
                              ? profile.nombre
                              : nombreCtrl.text.trim(),
                          fechaNacimiento: profile.fechaNacimiento,
                          genero: profile.genero,
                          origen: origenCtrl.text.trim().isEmpty
                              ? profile.origen
                              : origenCtrl.text.trim(),
                          estudios: estudiosCtrl.text.trim().isEmpty
                              ? profile.estudios
                              : estudiosCtrl.text.trim(),
                          fumador: fumador,
                          mascotas: mascotas,
                          tienePiso: tienePiso,
                          precioAlquilerPorPersona: precio,
                          horario: horario,
                          bio: bioCtrl.text.trim().isEmpty
                              ? profile.bio
                              : bioCtrl.text.trim(),
                          fotoPerfil: profile.fotoPerfil,
                          intereses: profile.intereses,
                        );

                        await _firestore.saveUserProfile(updated);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nombreCtrl.dispose();
    origenCtrl.dispose();
  estudiosCtrl.dispose();
    bioCtrl.dispose();
  precioCtrl.dispose();
  }

  String _generarBioIA(
    String nombre,
    String horario,
    bool fumador,
    bool mascotas,
  ) {
    final nombreSeguro = nombre.isEmpty ? 'Esta persona' : nombre;
    final fumadorTxt = fumador ? 'tiene habito de fumar' : 'no fuma';
    final mascotasTxt = mascotas
        ? 'convive bien con mascotas'
        : 'prefiere ambientes sin mascotas';
    return '$nombreSeguro busca convivencia respetuosa, con comunicacion clara y buena organizacion del piso. Su ritmo principal es de $horario, $fumadorTxt y $mascotasTxt. Le interesa mantener limpieza y acuerdos semanales.';
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<UserProfile?>(
      stream: _firestore.myProfileStream(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final isLocalPath = profile.fotoPerfil.startsWith('/');
        final ImageProvider avatarImage = profile.fotoPerfil.isEmpty
            ? const NetworkImage(
                'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
              )
            : isLocalPath
            ? FileImage(File(profile.fotoPerfil))
            : NetworkImage(profile.fotoPerfil);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Perfil',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestiona tu informacion y preferencias',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        onTap: () => _pickProfilePhoto(profile),
                        borderRadius: BorderRadius.circular(58),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: avatarImage,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: InkWell(
                          onTap: () => _editarPerfil(profile),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    profile.nombre,
                    style: textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${profile.edad} anos · ${profile.genero} · ${profile.origen}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 18),
                _section('Sobre mi', profile.bio),
                const SizedBox(height: 12),
                _section(
                  'Habitos',
                  'Horario: ${profile.horario}\nFumador/a: ${profile.fumador ? 'Si' : 'No'}\nMascotas: ${profile.mascotas ? 'Si' : 'No'}\nTiene piso: ${profile.tienePiso ? 'Si' : 'No'}${profile.tienePiso && profile.precioAlquilerPorPersona != null ? '\nAlquiler por persona: ${profile.precioAlquilerPorPersona!.toStringAsFixed(0)} EUR/mes' : ''}',
                ),
                const SizedBox(height: 12),
                _section('Estudios', profile.estudios),
                const SizedBox(height: 12),
                _section('Intereses', profile.intereses.join(', ')),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesion'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
