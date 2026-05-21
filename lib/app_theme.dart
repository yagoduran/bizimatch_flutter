import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFFF4F8F6);
  static const Color surface = Color(0xFFFDFEFE);
  static const Color primary = Color(0xFF10B981);
  static const Color turquoise = Color(0xFF22D3EE);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFFA855F7);
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121A2A);
  static const Color darkTextPrimary = Color(0xFFF7FBF9);
  static const Color darkTextSecondary = Color(0xFFA7B7B0);
  static const Color textPrimary = Color(0xFF1C2A25);
  static const Color textSecondary = Color(0xFF6B7A74);
  static const List<Color> emeraldIndigo = [
    Color(0xFF10B981),
    Color(0xFF22D3EE),
    Color(0xFF6366F1),
  ];
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: emeraldIndigo,
  );
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xCCFFFFFF), Color(0x66FFFFFF), Color(0x14FFFFFF)],
  );

  // Motion tokens for a consistent native-feel across screens.
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 260);
  static const Duration motionSlow = Duration(milliseconds: 420);
  static const Duration motionNavigation = Duration(milliseconds: 320);
  static const Duration motionDiscoverSwipe = Duration(milliseconds: 240);
  static const Duration motionDiscoverSnap = Duration(milliseconds: 460);
  static const Duration motionListItem = Duration(milliseconds: 220);
  static const Duration motionChatMessage = Duration(milliseconds: 160);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionCurveEmphasized = Curves.easeInOutCubic;
  static const PageTransitionsTheme motionPageTransitions =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      );

  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: textSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: turquoise,
        tertiary: indigo,
        surface: surface,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      pageTransitionsTheme: motionPageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.56),
        foregroundColor: textPrimary,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: const Color(0xFFE4ECE7),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C2A25),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.74),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: turquoise, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: Color(0xFFDCEAE3)),
        backgroundColor: const Color(0xFFF4F8F6),
        selectedColor: const Color(0x1F10B981),
        labelStyle: const TextStyle(color: textPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return const Color(0xFFD2DCD7);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0x6610B981);
          }
          return const Color(0xFFDDE6E1);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shadowColor: primary.withValues(alpha: 0.48),
          elevation: 10,
          splashFactory: InkRipple.splashFactory,
          overlayColor: turquoise.withValues(alpha: 0.18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primary.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          splashFactory: InkRipple.splashFactory,
          overlayColor: turquoise.withValues(alpha: 0.12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          splashFactory: InkRipple.splashFactory,
          overlayColor: turquoise.withValues(alpha: 0.18),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 10,
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: darkTextPrimary,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: darkTextPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: darkTextSecondary,
      ),
    );

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: primary,
        secondary: turquoise,
        tertiary: indigo,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      pageTransitionsTheme: motionPageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground.withValues(alpha: 0.72),
        foregroundColor: darkTextPrimary,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.10),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF172033),
        contentTextStyle: const TextStyle(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        hintStyle: const TextStyle(color: darkTextSecondary),
        labelStyle: const TextStyle(color: darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: turquoise, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: primary.withValues(alpha: 0.20),
        labelStyle: const TextStyle(color: darkTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xE60B1220),
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shadowColor: primary.withValues(alpha: 0.58),
          elevation: 12,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primary.withValues(alpha: 0.34)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          foregroundColor: darkTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}
