import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme Names
enum AppThemeType { midnight, iron, toxic, light }

class AppTheme {
  static const _inputTheme = InputDecorationTheme(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    isDense: false,
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
  );

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
    visualDensity: VisualDensity.standard, // Updated to standard per requirement
    inputDecorationTheme: _inputTheme,
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
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: _inputTheme,
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
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: _inputTheme,
  );
  
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF546E7A), // Muted Blue Grey (Soft)
      secondary: Color(0xFF90A4AE),
      surface: Colors.white,
      background: Color(0xFFF5F7FA), // Soft Blue-Grey/Off-White
      onBackground: Color(0xFF2D3436), // Deep Charcoal
      onSurface: Color(0xFF2D3436),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xFF2D3436), 
      displayColor: const Color(0xFF2D3436),
    ),
    visualDensity: VisualDensity.standard,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Color(0x1A000000),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    inputDecorationTheme: _inputTheme,
  );
}

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.midnight) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_index') ?? 0;
    if (idx < AppThemeType.values.length) {
      state = AppThemeType.values[idx];
    }
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
    case AppThemeType.light: return AppTheme.light;
  }
});
