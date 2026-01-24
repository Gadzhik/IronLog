import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme Names
enum AppThemeType { midnight, iron, toxic, light }

class AppTheme {
  static const _inputTheme = InputDecorationTheme(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  );

  static final ThemeData midnight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00FFD1), // Neon Cyan
      secondary: Color(0xFF00BFA5),
      surface: Color(0xFF121212),
      background: Color(0xFF000000), // Pure Black
    ),
    scaffoldBackgroundColor: const Color(0xFF000000),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: _inputTheme,
  );

  static final ThemeData iron = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFFCC00), // Vibrant Gold
      secondary: Color(0xFFFFD600),
      surface: Color(0xFF1A1A1A),
      background: Color(0xFF050505),
    ),
    scaffoldBackgroundColor: const Color(0xFF050505),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: _inputTheme,
  );

  static final ThemeData toxic = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF39FF14), // Neon Green
      secondary: Color(0xFF32CD32),
      surface: Color(0xFF0D0D0D),
      background: Color(0xFF000000),
    ),
    scaffoldBackgroundColor: const Color(0xFF000000),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: _inputTheme,
  );
  
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF008080), // Teal
      secondary: Color(0xFF26A69A),
      surface: Colors.white,
      background: Color(0xFFF0F2F5), // Soft Light BG
      onBackground: Color(0xFF202124),
      onSurface: Color(0xFF202124),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xFF202124), 
      displayColor: const Color(0xFF202124),
    ),
    visualDensity: VisualDensity.standard,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 4,
      shadowColor: Color(0x0D000000),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: _inputTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
    )
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
