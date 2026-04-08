import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestNotificationPermissions();
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
      home: const SplashScreen(),
    );
  }
}
