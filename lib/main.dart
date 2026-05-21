import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

class _BiziMatchScrollBehavior extends MaterialScrollBehavior {
  const _BiziMatchScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestNotificationPermissions();
  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: const BiziMatchApp(),
    ),
  );
}

class BiziMatchApp extends StatelessWidget {
  const BiziMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final baseTheme = AppTheme.lightTheme();
    final darkTheme = AppTheme.darkTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BiziMatch',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.25,
            ),
          ),
          child: ScrollConfiguration(
            behavior: const _BiziMatchScrollBehavior(),
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                return false;
              },
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.outfitTextTheme(
          baseTheme.primaryTextTheme,
        ),
      ),
      darkTheme: darkTheme.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(darkTheme.textTheme),
        primaryTextTheme: GoogleFonts.outfitTextTheme(
          darkTheme.primaryTextTheme,
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
