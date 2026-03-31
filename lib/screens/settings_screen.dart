import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificacionesMensajes = true;
  bool _notificacionesCercanos = true;
  String _quienVePerfil = 'Todos';
  bool _ocultarTemporalmente = false;
  bool _isBusy = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedDatabase() async {
    if (_isBusy) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showInfo('Necesitas iniciar sesion para inicializar la base de datos.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final now = DateTime.now();
      final myRef = _firestore.collection('usuarios').doc(user.uid);

      await myRef.set({
        'uid': user.uid,
        'nombre': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Mi Perfil',
        'fechaNacimiento': Timestamp.fromDate(DateTime(1996, 6, 14)),
        'genero': 'Prefiero no decirlo',
        'origen': 'Madrid, Espana',
        'fumador': false,
        'mascotas': false,
        'horario': 'Manana',
        'bio':
            'Perfil inicial de BiziMatch. Busco convivencia respetuosa y ordenada.',
        'fotoPerfil':
            user.photoURL ??
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800',
        'intereses': ['Orden', 'Cocina', 'Deporte'],
        'updatedAt': FieldValue.serverTimestamp(),
        'seedOwnerUid': user.uid,
        'seedCreatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final competitors = [
        {
          'nombre': 'Sofia Martin',
          'fechaNacimiento': DateTime(1998, 3, 20),
          'genero': 'Mujer',
          'origen': 'Valencia, Espana',
          'fumador': false,
          'mascotas': true,
          'horario': 'Tarde',
          'bio':
              'Trabajo en marketing remoto y me encanta convivir con buen rollo.',
          'fotoPerfil':
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800',
          'intereses': ['Cocina', 'Yoga', 'Series'],
        },
        {
          'nombre': 'Daniel Ruiz',
          'fechaNacimiento': DateTime(1995, 11, 12),
          'genero': 'Hombre',
          'origen': 'Sevilla, Espana',
          'fumador': false,
          'mascotas': false,
          'horario': 'Noche',
          'bio':
              'Ingeniero de software, limpio y responsable con los gastos del piso.',
          'fotoPerfil':
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
          'intereses': ['Tecnologia', 'Gaming', 'Deporte'],
        },
        {
          'nombre': 'Lucia Fernandez',
          'fechaNacimiento': DateTime(2000, 1, 5),
          'genero': 'Mujer',
          'origen': 'Bilbao, Espana',
          'fumador': true,
          'mascotas': false,
          'horario': 'Manana',
          'bio':
              'Estudio un master y busco companeros tranquilos y organizados.',
          'fotoPerfil':
              'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=800',
          'intereses': ['Lectura', 'Musica', 'Orden'],
        },
      ];

      String? seededUserForChat;
      for (final competitor in competitors) {
        final profileRef = _firestore.collection('usuarios').doc();
        seededUserForChat ??= profileRef.id;
        await profileRef.set({
          'uid': profileRef.id,
          ...competitor,
          'fechaNacimiento': Timestamp.fromDate(
            competitor['fechaNacimiento'] as DateTime,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
          'seedOwnerUid': user.uid,
          'seedCreatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (seededUserForChat != null) {
        final ids = [user.uid, seededUserForChat]..sort();
        final chatId = ids.join('_');

        final chatRef = _firestore.collection('chats').doc(chatId);
        await chatRef.set({
          'participants': [user.uid, seededUserForChat],
          'lastMessage': 'Hola, te escribo por la habitacion disponible.',
          'updatedAt': FieldValue.serverTimestamp(),
          'seedOwnerUid': user.uid,
          'seedCreatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await chatRef.collection('mensajes').doc().set({
          'id': 'seed_${now.millisecondsSinceEpoch}',
          'text': 'Hola, te escribo por la habitacion disponible.',
          'fromUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _showInfo('Base de datos inicializada correctamente.');
    } catch (_) {
      _showInfo('No se pudo inicializar la base de datos.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ajustes',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configura tu cuenta, privacidad y soporte.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Cuenta',
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Editar email',
                  subtitle: 'Actualiza tu correo de acceso',
                  onTap: _editarEmail,
                ),
                _settingTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Cambiar contrasena',
                  subtitle: 'Te enviaremos un enlace por correo',
                  onTap: _cambiarContrasena,
                ),
                _settingTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Verificacion de identidad',
                  subtitle: _auth.currentUser?.emailVerified == true
                      ? 'Cuenta verificada'
                      : 'Verifica tu email para mayor confianza',
                  onTap: _verificarIdentidad,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Notificaciones',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  value: _notificacionesMensajes,
                  title: const Text('Nuevos mensajes'),
                  subtitle: const Text('Alertas cuando recibas mensajes.'),
                  onChanged: (value) {
                    setState(() => _notificacionesMensajes = value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  value: _notificacionesCercanos,
                  title: const Text('Nuevos companeros cerca'),
                  subtitle: const Text('Sugerencias por zona y afinidad.'),
                  onChanged: (value) {
                    setState(() => _notificacionesCercanos = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Privacidad',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.visibility_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  title: const Text('Quien puede ver mi perfil'),
                  subtitle: Text(_quienVePerfil),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _quienVePerfil,
                      borderRadius: BorderRadius.circular(14),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'Solo verificados',
                          child: Text('Solo verificados'),
                        ),
                        DropdownMenuItem(
                          value: 'Solo mis contactos',
                          child: Text('Solo mis contactos'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _quienVePerfil = value);
                      },
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  value: _ocultarTemporalmente,
                  title: const Text('Ocultar mi perfil temporalmente'),
                  subtitle: const Text(
                    'Tu perfil no aparecera en Explorar mientras este activo.',
                  ),
                  onChanged: (value) {
                    setState(() => _ocultarTemporalmente = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Soporte',
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Centro de ayuda',
                  subtitle: 'Preguntas frecuentes y contacto',
                  onTap: () => _showInfo(
                    'Centro de ayuda disponible proximamente en la version web.',
                  ),
                ),
                _settingTile(
                  icon: Icons.description_outlined,
                  title: 'Terminos y condiciones',
                  subtitle: 'Condiciones de uso y privacidad',
                  onTap: () => _showInfo(
                    'Terminos y condiciones disponibles proximamente.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : seedDatabase,
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('🚀', style: TextStyle(fontSize: 20)),
              label: const Text(
                'INICIALIZAR BASE DE DATOS',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Acciones',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    'Cerrar sesion',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: _isBusy ? null : _cerrarSesion,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Eliminar cuenta',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Esta accion es permanente.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  onTap: _isBusy ? null : _confirmarEliminarCuenta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9F0EC)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Future<void> _editarEmail() async {
    final controller = TextEditingController(
      text: _auth.currentUser?.email ?? '',
    );

    final nuevoEmail = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar email'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Nuevo email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevoEmail == null || nuevoEmail.isEmpty) {
      return;
    }

    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(nuevoEmail);
      if (!mounted) {
        return;
      }
      _showInfo('Te enviamos un correo de verificacion al nuevo email.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No se pudo actualizar el email: ${e.code}');
    }
  }

  Future<void> _cambiarContrasena() async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showInfo('Tu cuenta no tiene email asociado.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showInfo('Revisa tu correo para cambiar la contrasena.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No se pudo enviar el correo: ${e.code}');
    }
  }

  Future<void> _verificarIdentidad() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showInfo('No hay sesion activa.');
      return;
    }

    if (user.emailVerified) {
      _showInfo('Tu identidad ya esta verificada.');
      return;
    }

    try {
      await user.sendEmailVerification();
      _showInfo('Te enviamos un correo para verificar tu identidad.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No fue posible enviar la verificacion: ${e.code}');
    }
  }

  Future<void> _cerrarSesion() async {
    setState(() => _isBusy = true);
    try {
      await _auth.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    } catch (_) {
      _showInfo('No se pudo cerrar sesion.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _confirmarEliminarCuenta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text(
            'Esta accion eliminara tu cuenta y tu perfil. No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showInfo('No hay sesion activa.');
        return;
      }

      await _firestore.collection('usuarios').doc(user.uid).delete();
      await user.delete();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showInfo(
          'Por seguridad, vuelve a iniciar sesion antes de eliminar la cuenta.',
        );
      } else {
        _showInfo('No se pudo eliminar la cuenta: ${e.code}');
      }
    } catch (_) {
      _showInfo('No se pudo eliminar la cuenta.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showInfo(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
