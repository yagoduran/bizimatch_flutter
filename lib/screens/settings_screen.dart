import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/feature_tour_service.dart';
import '../services/firestore_service.dart';
import '../services/demo_service.dart';
import '../services/notification_service.dart';
import '../widgets/glassmorphism.dart';
import 'login_screen.dart';

/// SettingsScreen: aplikazioaren konfigurazio orokorrak eta ekintza-tresnak.
///
/// Erabiltzaileak kontuari, pribatutasunari, demoari eta datuen esportazioari
/// lotutako konfigurazioak hemen kudeatzen dira.
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
  final AuthService _authService = AuthService();
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
        // Dokumentutik kargatu eta UI eguneratu; null segurtasunarekin.
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
      // Egiaztatu sarrera eta eguneratu erabiltzaile dokumentua Firestore-n.
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

    // Reset demo local eta, posiblee del caso, datos Firestore de demo.
    if (mounted) {
      _showInfo('Demo reiniciada: mazo, chats y BiziPuntos a cero.');
    }
  }

  Future<void> _triggerDemoNotification() async {
    HapticFeedback.mediumImpact();
    await NotificationService.instance.triggerDemoNotification();
    if (mounted) {
      _showInfo('Notificacion demo programada para dentro de 10 segundos.');
    }
  }

  Future<void> _resetAndReplayTutorial() async {
    HapticFeedback.mediumImpact();
    await FeatureTourService.instance.resetTutorialProgress();
    FeatureTourService.instance.requestReplay();
    if (mounted) {
      _showInfo('Tutorial reiniciado. Volvemos a enseñarlo desde Explorar.');
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
    final themeProvider = context.watch<ThemeProvider>();
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
            title: 'Apariencia (Itxura)',
            child: _buildThemeSection(context, themeProvider),
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
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: isDemo ? _resetAndReplayTutorial : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Repetir tutorial guiado'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _triggerDemoNotification,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Probar notificacion demo'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuenta de presentación',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Elige quien eres en la demo. Al cambiar, se reinicia el mazo para ensenar un match limpio.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: DemoService.instance.demoProfiles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final p = DemoService.instance.demoProfiles[index];
                          final selected =
                              DemoService
                                  .instance
                                  .selectedDemoUser
                                  .value
                                  ?.uid ==
                              p.uid;
                          return GestureDetector(
                            onTap: DemoService.instance.isDemoMode.value
                                ? () {
                                    DemoService.instance.selectDemoUserByUid(
                                      p.uid,
                                    );
                                    setState(() {});
                                    _showInfo(
                                      'Cuenta demo activa: ${p.nombre}. Ve a Explorar y da like para mostrar el match.',
                                    );
                                  }
                                : null,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundImage: AssetImage(
                                          p.fotoPerfil,
                                        ),
                                      ),
                                      if (selected)
                                        const Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor: AppTheme.primary,
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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
                                      color: selected
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                      fontWeight: selected
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _section(
            title: 'RGPD',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestiona tu información personal, exporta tus datos o elimina tu cuenta.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _descargarMisDatos,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('Descargar mis datos'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () {
                            if (DemoService.instance.isDemoMode.value) {
                              HapticFeedback.selectionClick();
                              _showInfo(
                                'Modo Demo activo â€” no se puede eliminar cuenta demo.',
                              );
                              return;
                            }
                            HapticFeedback.heavyImpact();
                            _confirmarEliminarCuenta();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD61F1F),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Eliminar mi cuenta'),
                  ),
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

  Widget _buildThemeSection(BuildContext context, ThemeProvider themeProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Colors.white.withValues(alpha: isDark ? 0.10 : 0.55);
    final backgroundColor = Colors.white.withValues(
      alpha: isDark ? 0.04 : 0.52,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Elige cómo quieres ver BiziMatch en tiempo real.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Text('☀️'),
                label: Text('Claro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Text('🌙'),
                label: Text('Oscuro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Text('📱'),
                label: Text('Sistema'),
              ),
            ],
            selected: <ThemeMode>{themeProvider.themeMode},
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white70 : const Color(0xFF475467);
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF2ECC71);
                }
                return Colors.transparent;
              }),
              side: WidgetStateProperty.all(BorderSide.none),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            onSelectionChanged: (selection) {
              final selectedMode = selection.first;
              HapticFeedback.selectionClick();
              context.read<ThemeProvider>().toggleTheme(selectedMode);
            },
          ),
        ),
      ],
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
      DemoService.instance.enableDemo(false);
      await _authService.clearDemoAdminSession();
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

    if (!mounted) {
      return;
    }

    final handledByNewFlow = ModalRoute.of(context) != null;
    if (handledByNewFlow) {
      await _eliminarMiCuenta();
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

  Future<void> _eliminarMiCuenta() async {
    setState(() => _isBusy = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showInfo('No hay sesiÃ³n activa.');
        return;
      }

      await _firestore.collection('usuarios').doc(user.uid).delete();
      final usersDoc = _firestore.collection('users').doc(user.uid);
      final usersSnapshot = await usersDoc.get();
      if (usersSnapshot.exists) {
        await usersDoc.delete();
      }
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
    } on FirebaseException catch (e) {
      _showInfo('No se pudo eliminar la cuenta: ${e.message ?? e.code}');
    } catch (e) {
      _showInfo('No se pudo eliminar la cuenta: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _descargarMisDatos() async {
    setState(() => _isBusy = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showInfo('No hay sesiÃ³n activa.');
        return;
      }

      final usuariosSnapshot = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final usersSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final exportPayload = <String, dynamic>{
        'exportedAt': DateTime.now().toIso8601String(),
        'firebaseAuth': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'phoneNumber': user.phoneNumber,
          'emailVerified': user.emailVerified,
          'isAnonymous': user.isAnonymous,
          'creationTime': user.metadata.creationTime?.toIso8601String(),
          'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        },
        'firestore': {
          'usuarios': _normalizeFirestoreValue(usuariosSnapshot.data()),
          'users': _normalizeFirestoreValue(usersSnapshot.data()),
        },
      };

      // Esportazio JSON bat prestatu eta partekatzeko fitxategi gisa gordeko dugu.
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}\\bizimatch_datos_${user.uid}.json');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(_normalizeFirestoreValue(exportPayload)),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'Exportación RGPD de tus datos de BiziMatch.',
          subject: 'Mis datos de BiziMatch',
        ),
      );

      if (mounted) {
        _showInfo('Tu exportación de datos está lista para compartir.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showInfo(
          'Por seguridad, vuelve a iniciar sesión antes de descargar tus datos.',
        );
      } else {
        _showInfo('No se pudieron descargar tus datos: ${e.code}');
      }
    } on FirebaseException catch (e) {
      _showInfo(
        'Error de Firebase al exportar tus datos: ${e.message ?? e.code}',
      );
    } catch (e) {
      _showInfo('No se pudieron descargar tus datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  dynamic _normalizeFirestoreValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeFirestoreValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_normalizeFirestoreValue).toList(growable: false);
    }
    return value;
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
