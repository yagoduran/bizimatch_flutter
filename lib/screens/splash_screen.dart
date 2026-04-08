import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  Widget? _destination;
  bool _isReady = false;
  bool _timerElapsed = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    Timer(const Duration(seconds: 3), () {
      _timerElapsed = true;
      _navigateIfReady();
    });
  }

  Future<void> _checkSession() async {
    final User? user = await _authService.authStateChanges().first;

    if (!mounted) {
      return;
    }

    setState(() {
      _destination = user != null ? const MainScaffold() : const LoginScreen();
      _isReady = true;
    });

    _navigateIfReady();
  }

  void _navigateIfReady() {
    if (!mounted || !_isReady || !_timerElapsed || _destination == null) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => _destination!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
