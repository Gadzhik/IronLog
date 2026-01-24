import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { onyx, cyberpunk, forest }

class AppTheme {
  static const double radius = 24.0;

  static final ThemeData onyxGold = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD4AF37), // Metallic Gold
      secondary: Color(0xFFB8860B),
      surface: Color(0xFF111111),
      background: Color(0xFF0D0D0D), // Matte Black
      onBackground: Color(0xFFE0E0E0),
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37)),
      headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
      titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF111111),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.bebasNeue(
        fontSize: 32,
        letterSpacing: 2,
        color: const Color(0xFFD4AF37),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111111),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.black,
      indicatorColor: const Color(0xFFD4AF37).withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
    ),
  );

  static final ThemeData cyberPunk = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00FFD1), // Cyan
      secondary: Color(0xFFFF00FF), // Magenta
      surface: Color(0xFF121212),
      background: Color(0xFF050505),
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF050505),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF00FFD1)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      titleTextStyle: GoogleFonts.bebasNeue(fontSize: 32, color: const Color(0xFF00FFD1), letterSpacing: 2),
    ),
  );

  static final ThemeData deepForest = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2ECC71), // Emerald
      secondary: Color(0xFF27AE60),
      surface: Color(0xFF141D15),
      background: Color(0xFF0A120B),
      onBackground: Color(0xFFE0E0E0),
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A120B),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF2ECC71)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      titleTextStyle: GoogleFonts.bebasNeue(fontSize: 32, color: const Color(0xFF2ECC71), letterSpacing: 2),
    ),
  );
}

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.onyx) {
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
    case AppThemeType.onyx:
      return AppTheme.onyxGold;
    case AppThemeType.cyberpunk:
      return AppTheme.cyberPunk;
    case AppThemeType.forest:
      return AppTheme.deepForest;
  }
});
