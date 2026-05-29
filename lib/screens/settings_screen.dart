import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _precioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosVivienda();
  }

  @override
  void dispose() {
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosVivienda() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final data = doc.data();
      if (!mounted || data == null) {
        return;
      }
      setState(() {
        _tienePiso = data['tienePiso'] ?? false;
        _precioAlquiler = data['precioAlquilerPorPersona']?.toString() ?? '';
        _precioController.text = _precioAlquiler;
      });
    } catch (_) {
      // Silently ignore bootstrap issues.
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

  Future<void> _editarEmail() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showInfo('No hay sesión activa.');
      return;
    }

    final controller = TextEditingController(text: user.email);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty || newEmail == user.email) {
      return;
    }

    try {
      await user.updateEmail(newEmail);
      _showInfo('Email actualizado.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No fue posible actualizar el correo: ${e.code}');
    }
  }

  Future<void> _cambiarContrasena() async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      _showInfo('No hay sesión activa.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showInfo('Te enviamos un enlace para cambiar tu contraseña.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No fue posible enviar el enlace: ${e.code}');
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
      await _authService.logout();
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text('Esta acción eliminará tu cuenta y tus datos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
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
    } catch (e) {
      _showInfo('No se pudo eliminar la cuenta: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _descargarMisDatos() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showInfo('No hay sesión activa.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email,
        'profile': doc.data() ?? <String, dynamic>{},
      };

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/buzimatch_mis_datos.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mis datos de BiziMatch',
      );
    } catch (e) {
      _showInfo('No se pudieron exportar tus datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

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

  Future<void> _guardarAjustesRapidos() async {
    HapticFeedback.selectionClick();
    await _guardarDatosVivienda();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                title: 'Privacidad',
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _ocultarTemporalmente,
                      title: const Text('Ocultar perfil temporalmente'),
                      subtitle: const Text('Desactiva tu perfil sin borrarlo.'),
                      onChanged: (value) => setState(
                        () => _ocultarTemporalmente = value,
                      ),
                    ),
                    const Divider(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _notificacionesMensajes,
                      title: const Text('Nuevos mensajes'),
                      subtitle: const Text('Recibe avisos cuando te escriban.'),
                      onChanged: _onNuevosMensajesChanged,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _notificacionesCercanos,
                      title: const Text('Alertas cercanas'),
                      subtitle: const Text('Notificaciones de actividad útil.'),
                      onChanged: (value) => setState(
                        () => _notificacionesCercanos = value,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _quienVePerfil,
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'Solo vínculos',
                          child: Text('Solo vínculos'),
                        ),
                        DropdownMenuItem(value: 'Nadie', child: Text('Nadie')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _quienVePerfil = value);
                      },
                      decoration: const InputDecoration(
                        labelText: '¿Quién ve tu perfil?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Apariencia',
                child: _buildThemeSection(themeProvider),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Mi casa',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _tienePiso,
                      title: const Text('Tengo piso'),
                      subtitle: const Text('Indica si publicas una vivienda.'),
                      onChanged: (value) => setState(() => _tienePiso = value),
                    ),
                    if (_tienePiso) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _precioController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio por persona',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _precioAlquiler = value,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isBusy ? null : _guardarAjustesRapidos,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar casa'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Datos y cuenta',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _descargarMisDatos,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Descargar mis datos'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _confirmarEliminarCuenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD61F1F),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Eliminar mi cuenta'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _cerrarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'La versión de producción elimina la demo local y usa solo Firebase.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Información de BiziMatch',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<ThemeMode>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sistema'),
          value: ThemeMode.system,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.toggleTheme(value!),
        ),
        RadioListTile<ThemeMode>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Claro'),
          value: ThemeMode.light,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.toggleTheme(value!),
        ),
        RadioListTile<ThemeMode>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Oscuro'),
          value: ThemeMode.dark,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.toggleTheme(value!),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
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
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
