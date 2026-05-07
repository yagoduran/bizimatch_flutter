import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/glassmorphism.dart';
import 'main_scaffold.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showInfo('Completa email y contraseña.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.login(email: email, password: password);
      await NotificationService.instance.syncTokenForCurrentUser();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const MainScaffold()),
      );
    } on FirebaseAuthException catch (e) {
      _showInfo('Error al iniciar sesión: ${e.code}');
    } catch (_) {
      _showInfo('No se pudo iniciar sesión. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recuperarContrasena() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'tuemail@dominio.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) {
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showInfo('Te hemos enviado un correo para restablecer tu contraseña.');
    } on FirebaseAuthException catch (e) {
      _showInfo('No se pudo enviar el correo: ${e.code}');
    }
  }

  void _showInfo(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOrganicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 34,
                  padding: const EdgeInsets.all(26),
                  glowColor: AppTheme.indigo,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 94,
                          height: 94,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.42),
                                blurRadius: 28,
                                spreadRadius: -5,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const Text(
                        'BiziMatch',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Encuentra compañeros de piso compatibles',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electronico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _recuperarContrasena,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppTheme.primary,
                        ),
                        label: const Text(
                          'Crear cuenta completa',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
