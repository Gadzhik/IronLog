import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { onyx, cyberpunk, toxic, sea }

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

  static final ThemeData toxicNight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFADFF2F), // Neon Lime
      secondary: Color(0xFF7FFF00),
      surface: Color(0xFF1A1A1A),
      background: Color(0xFF0F0F0F),
      onBackground: Color(0xFFE0E0E0),
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFADFF2F)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      titleTextStyle: GoogleFonts.bebasNeue(fontSize: 32, color: const Color(0xFFADFF2F), letterSpacing: 2),
    ),
  );

  static final ThemeData deepSea = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF0077FF), // Electric Blue
      secondary: Color(0xFF0055CC),
      surface: Color(0xFF05151F),
      background: Color(0xFF010C13),
      onBackground: Color(0xFFE0E0E0),
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF010C13),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF0077FF)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      titleTextStyle: GoogleFonts.bebasNeue(fontSize: 32, color: const Color(0xFF0077FF), letterSpacing: 2),
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
    if (idx >= 0 && idx < AppThemeType.values.length) {
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
    case AppThemeType.toxic:
      return AppTheme.toxicNight;
    case AppThemeType.sea:
      return AppTheme.deepSea;
  }
});
