import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme Names
enum AppThemeType { midnight, iron, toxic }

class AppTheme {
  static final ThemeData midnight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64B5F6), // Blue
      secondary: Color(0xFF1E88E5),
      surface: Color(0xFF0D1117), // Dark Blue Grey
      background: Color(0xFF010409),
    ),
    scaffoldBackgroundColor: const Color(0xFF010409),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.compact,
  );

  static final ThemeData iron = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFF9800), // Orange
      secondary: Color(0xFFF57C00),
      surface: Color(0xFF212121), // Grey
      background: Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.compact,
  );

  static final ThemeData toxic = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E676), // Neon Green
      secondary: Color(0xFF00C853),
      surface: Color(0xFF263238), // Charcoal
      background: Color(0xFF1C2326),
    ),
    scaffoldBackgroundColor: const Color(0xFF1C2326),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.compact,
  );
}

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.midnight) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_index') ?? 0;
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
    case AppThemeType.midnight: return AppTheme.midnight;
    case AppThemeType.iron: return AppTheme.iron;
    case AppThemeType.toxic: return AppTheme.toxic;
  }
});
