import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_scaffold.dart';
import 'onboarding_screen.dart';

/// SplashScreen: hasierako pantaila — sesio-egoera eta onboarding egiaztatzen ditu.
///
  /// Arau praktikoa: 3 segundo itxaroten du eta aldi berean sesioa egiaztatzen du.
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
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    final User? user = await _authService.authStateChanges().first;

    if (!mounted) {
      return;
    }
    // Erabiltzailearen egoera aztertu eta helmuga egokia aukeratu.
    setState(() {
      _destination = user != null
          ? const MainScaffold()
          : hasSeenOnboarding
          ? const LoginScreen()
          : const OnboardingScreen();
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
