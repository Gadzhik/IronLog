import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { light, toxic, midnight }

class AppTheme {
  // Common BorderRadius
  static const double radius = 24.0;

  static final ThemeData softLight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF48A9A6), // Muted Emerald
      secondary: Color(0xFF4ECDC4),
      surface: Colors.white,
      background: Color(0xFFF2F4F7), // Soft Bone
      onBackground: Color(0xFF2D3436), // Deep Navy
      onSurface: Color(0xFF2D3436),
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F4F7),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
      titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
    ).apply(
      bodyColor: const Color(0xFF2D3436),
      displayColor: const Color(0xFF2D3436),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xFF2D3436), 
        fontSize: 20, 
        fontWeight: FontWeight.w800
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  static final ThemeData toxicNight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFADFF2F), // Neon Lime
      secondary: Color(0xFF7000FF), // Deep Violet
      surface: Color(0xFF121212),
      background: Color(0xFF000000), // Pure Black
    ),
    scaffoldBackgroundColor: const Color(0xFF000000),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
      titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF121212),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20, 
        fontWeight: FontWeight.w800
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF121212),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  static final ThemeData midnightBlue = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00D2FF), // Electric Blue
      secondary: Color(0xFFFF007A), // Fuchsia
      surface: Color(0xFF021627),
      background: Color(0xFF010B13), // Deep Blue
    ),
    scaffoldBackgroundColor: const Color(0xFF010B13),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      color: const Color(0xFF021627),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
  );
}

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.midnight) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_index') ?? 2; // Default to Midnight
    state = AppThemeType.values[idx];
  }

  Future<void> setTheme(AppThemeType type) async {
    state = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', type.index);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) {
  return ThemeNotifier();
});

final currentThemeProvider = Provider<ThemeData>((ref) {
  final type = ref.watch(themeProvider);
  switch (type) {
    case AppThemeType.light:
      return AppTheme.softLight;
    case AppThemeType.toxic:
      return AppTheme.toxicNight;
    case AppThemeType.midnight:
      return AppTheme.midnightBlue;
  }
});
