import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { light, toxic, midnight }

class AppTheme {
  static final ThemeData softLight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4ECDC4), // Soft Teal
      secondary: Color(0xFFFF6B6B),
      surface: Colors.white,
      background: Color(0xFFFDFCF0), // Cream
      onBackground: Color(0xFF2D3436), // Deep Grey
      onSurface: Color(0xFF2D3436),
    ),
    scaffoldBackgroundColor: const Color(0xFFFDFCF0),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xFF2D3436),
      displayColor: const Color(0xFF2D3436),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: Color(0xFF2D3436), fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  static final ThemeData toxicNight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFADFF2F), // Neon Lime
      secondary: Color(0xFF7000FF), // Toxic Purple
      surface: Color(0xFF1A1A1A),
      background: Color(0xFF0F0F0F), // Deep Black
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
