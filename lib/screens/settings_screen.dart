import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
import '../services/firestore_service.dart';
import '../services/demo_service.dart';
import '../widgets/glassmorphism.dart';
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
  bool _tienePiso = false;
  String _precioAlquiler = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _onNuevosMensajesChanged(bool value) async {
    HapticFeedback.selectionClick();
    if (!value) {
      setState(() => _notificacionesMensajes = false);
      return;
    }

    var status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }

    if (status.isGranted || status.isLimited || status.isProvisional) {
      setState(() => _notificacionesMensajes = true);
      return;
    }

    setState(() => _notificacionesMensajes = false);
    _showInfo(
      'Necesitas permitir notificaciones para activar "Nuevos mensajes".',
    );

    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosVivienda();
  }

  Future<void> _cargarDatosVivienda() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _tienePiso = data?['tienePiso'] ?? false;
          _precioAlquiler = data?['precioAlquilerPorPersona']?.toString() ?? '';
        });
      }
    } catch (_) {
      // Silenciosamente ignorar errores de carga
    }
  }

  Future<void> _guardarDatosVivienda() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    if (_tienePiso && _precioAlquiler.trim().isEmpty) {
      _showInfo('Por favor, ingresa el precio de alquiler por persona.');
      return;
    }

    if (_tienePiso) {
      final precioNum = int.tryParse(_precioAlquiler.trim());
      if (precioNum == null || precioNum <= 0) {
        _showInfo('El precio debe ser un número válido mayor que cero.');
        return;
      }
    }

    setState(() => _isBusy = true);
    try {
      final update = <String, dynamic>{
        'tienePiso': _tienePiso,
        if (_tienePiso) 'precioAlquilerPorPersona': int.parse(_precioAlquiler),
        if (!_tienePiso) 'precioAlquilerPorPersona': null,
      };
      await _firestore.collection('usuarios').doc(user.uid).update(update);
      if (mounted) {
        _showInfo('Datos de vivienda actualizados.');
      }
    } catch (e) {
      if (mounted) {
        _showInfo('Error al guardar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _resetDemoData() async {
    HapticFeedback.mediumImpact();
    DemoService.instance.resetDemoData();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('usuarios').doc(user.uid).set({
          'biziPuntos': 0,
          'rachaDias': 0,
          'semanasPerfectas': 0,
          'comodinRachaDisponible': true,
          'swipesDiarios': 0,
        }, SetOptions(merge: true));
      } catch (_) {
        // El reset demo local no debe fallar por conectividad en la presentación.
      }
    }

    if (mounted) {
      _showInfo('Demo reiniciada: mazo, chats y BiziPuntos a cero.');
    }
  }

  Future<void> seedDatabase() async {
    if (_isBusy) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showInfo('Necesitas iniciar sesión para inicializar la base de datos.');
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
        'origen': 'Madrid, España',
        'estudios': 'Arquitectura',
        'fumador': false,
        'mascotas': false,
        'tienePiso': false,
        'horario': 'Manana',
        'bio':
            'Perfil inicial de BiziMatch. Busco convivencia respetuosa y ordenada.',
        'fotoPerfil':
            user.photoURL ??
            'https://source.unsplash.com/featured/?student,portrait',
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
          'origen': 'Valencia, España',
          'estudios': 'Publicidad',
          'fumador': false,
          'mascotas': true,
          'tienePiso': true,
          'precioAlquilerPorPersona': 430,
          'horario': 'Tarde',
          'bio':
              'Trabajo en marketing remoto y me encanta convivir con buen rollo.',
          'fotoPerfil':
              'https://source.unsplash.com/featured/?young,woman,portrait',
          'intereses': ['Cocina', 'Yoga', 'Series'],
        },
        {
          'nombre': 'Daniel Ruiz',
          'fechaNacimiento': DateTime(1995, 11, 12),
          'genero': 'Hombre',
          'origen': 'Sevilla, España',
          'estudios': 'Ingeniería informática',
          'fumador': false,
          'mascotas': false,
          'tienePiso': false,
          'horario': 'Noche',
          'bio':
              'Ingeniero de software, limpio y responsable con los gastos del piso.',
          'fotoPerfil':
              'https://source.unsplash.com/featured/?young,man,portrait',
          'intereses': ['Tecnologia', 'Gaming', 'Deporte'],
        },
        {
          'nombre': 'Lucia Fernandez',
          'fechaNacimiento': DateTime(2000, 1, 5),
          'genero': 'Mujer',
          'origen': 'Bilbao, España',
          'estudios': 'Master en psicologia',
          'fumador': true,
          'mascotas': false,
          'tienePiso': true,
          'precioAlquilerPorPersona': 380,
          'horario': 'Manana',
          'bio':
              'Estudio un máster y busco compañeros tranquilos y organizados.',
          'fotoPerfil': 'https://source.unsplash.com/featured/?student,room',
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
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Ajustes', style: textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(
            'Configura tu cuenta, privacidad y soporte.',
            style: textTheme.bodyMedium,
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
                  title: 'Cambiar contraseña',
                  subtitle: 'Te enviaremos un enlace por correo',
                  onTap: _cambiarContrasena,
                ),
                _settingTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Verificación de identidad',
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
            title: 'Configuración de Presentación',
            child: ValueListenableBuilder<bool>(
              valueListenable: DemoService.instance.isDemoMode,
              builder: (context, isDemo, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.primary,
                      value: isDemo,
                      title: const Text('Activar Modo Demo'),
                      subtitle: const Text(
                        'Usar perfiles y chats locales sin conexión.',
                      ),
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        DemoService.instance.enableDemo(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _resetDemoData,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Resetear Datos de Demo'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuenta de presentación',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: DemoService.instance.demoProfiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final p = DemoService.instance.demoProfiles[index];
                          return GestureDetector(
                            onTap: DemoService.instance.isDemoMode.value
                                ? () {
                                    DemoService.instance.selectDemoUserByUid(
                                      p.uid,
                                    );
                                    setState(() {});
                                  }
                                : null,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: AssetImage(p.fotoPerfil),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    p.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          DemoService
                                                  .instance
                                                  .selectedDemoUser
                                                  .value
                                                  ?.uid ==
                                              p.uid
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _section(
            title: 'Notificaciones',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                  value: _notificacionesMensajes,
                  title: const Text('Nuevos mensajes'),
                  subtitle: const Text('Alertas cuando recibas mensajes.'),
                  onChanged: _onNuevosMensajesChanged,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                  value: _notificacionesCercanos,
                  title: const Text('Nuevos compañeros cerca'),
                  subtitle: const Text('Sugerencias por zona y afinidad.'),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(
                        Icons.visibility_outlined,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _quienVePerfil,
                        decoration: const InputDecoration(
                          labelText: 'Quién puede ver mi perfil',
                        ),
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(
                            value: 'Todos',
                            child: Text('Todos'),
                          ),
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
                          HapticFeedback.selectionClick();
                          setState(() => _quienVePerfil = value);
                        },
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                  value: _ocultarTemporalmente,
                  title: const Text('Ocultar mi perfil temporalmente'),
                  subtitle: const Text(
                    'Tu perfil no aparecerá en Explorar mientras esté activo.',
                  ),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _ocultarTemporalmente = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Vivienda',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                  value: _tienePiso,
                  title: const Text('Tengo piso ya'),
                  subtitle: const Text('Indicar si dispones de vivienda.'),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _tienePiso = value);
                  },
                ),
                if (_tienePiso)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      enabled: !_isBusy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Precio alquiler por persona (EUR/mes)',
                        hintText: 'ej: 400',
                      ),
                      onChanged: (value) =>
                          setState(() => _precioAlquiler = value),
                      controller: TextEditingController(text: _precioAlquiler),
                    ),
                  ),
                if (_tienePiso)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isBusy ? null : _guardarDatosVivienda,
                        child: _isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar datos de vivienda'),
                      ),
                    ),
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
                    'Centro de ayuda disponible próximamente en la versión web.',
                  ),
                ),
                _settingTile(
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  subtitle: 'Condiciones de uso y privacidad',
                  onTap: () => _showInfo(
                    'Términos y condiciones disponibles próximamente.',
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
              onPressed: _isBusy
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _poblarEspana();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('🔥', style: TextStyle(fontSize: 20)),
              label: const Text(
                'POBLAR ESPAÑA (50 Vínculos)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _isBusy
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      if (DemoService.instance.isDemoMode.value) {
                        _showInfo('Modo Demo activo — acción deshabilitada.');
                        return;
                      }
                      seedDatabase();
                    },
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
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: _isBusy
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _cerrarSesion();
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Color(0xFFD61F1F),
                  ),
                  title: const Text(
                    'Eliminar cuenta y datos',
                    style: TextStyle(
                      color: Color(0xFFD61F1F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Acción irreversible: elimina Auth y Firestore.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  onTap: _isBusy
                      ? null
                      : () {
                          if (DemoService.instance.isDemoMode.value) {
                            HapticFeedback.selectionClick();
                            _showInfo(
                              'Modo Demo activo — no se puede eliminar cuenta demo.',
                            );
                            return;
                          }
                          HapticFeedback.heavyImpact();
                          _confirmarEliminarCuenta();
                        },
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  Widget _section({required String title, required Widget child}) {
    return GlassCard(
      borderRadius: 28,
      glowColor: AppTheme.turquoise,
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
      _showInfo('Te enviamos un correo de verificación al nuevo email.');
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
      _showInfo('Revisa tu correo para cambiar la contraseña.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No se pudo enviar el correo: ${e.code}');
    }
  }

  Future<void> _verificarIdentidad() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showInfo('No hay sesión activa.');
      return;
    }

    if (user.emailVerified) {
      _showInfo('Tu identidad ya está verificada.');
      return;
    }

    try {
      await user.sendEmailVerification();
      _showInfo('Te enviamos un correo para verificar tu identidad.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No fue posible enviar la verificación: ${e.code}');
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
      _showInfo('No se pudo cerrar sesión.');
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
          title: const Text('Confirmación estricta'),
          content: const Text(
            'Se eliminará tu cuenta de Firebase Auth y tus datos en Firestore. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD61F1F),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, eliminar definitivamente'),
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
        _showInfo('No hay sesión activa.');
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
          'Por seguridad, vuelve a iniciar sesión antes de eliminar la cuenta.',
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

  Future<void> _poblarEspana() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _firestoreService.poblarEspana();
      if (mounted) {
        _showInfo('¡España poblada con 50 Vínculos realistas!');
      }
    } catch (e) {
      if (mounted) {
        _showInfo('Error al poblar España: $e');
      }
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
