import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BiziMatchApp());
}

class BiziMatchApp extends StatelessWidget {
  const BiziMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = AppTheme.lightTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BiziMatch',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.poppinsTextTheme(
          baseTheme.primaryTextTheme,
        ),
      ),
      home: const _FirebaseBootstrap(),
    );
  }
}

class _FirebaseBootstrap extends StatelessWidget {
  const _FirebaseBootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No se pudo inicializar Firebase.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return const SplashScreen();
      },
    );
  }
}
