import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { onyx, cyberpunk, toxic, sea, emerald, amethyst }

class AppTheme {
  static const double radius = 24.0;

  static final ThemeData onyxGold = _baseTheme(
    primary: const Color(0xFFD4AF37),
    background: const Color(0xFF0D0D0D),
    surface: const Color(0xFF111111),
  );

  static final ThemeData cyberPunk = _baseTheme(
    primary: const Color(0xFF00FFD1),
    background: const Color(0xFF050505),
    surface: const Color(0xFF121212),
  );

  static final ThemeData toxicNight = _baseTheme(
    primary: const Color(0xFFADFF2F),
    background: const Color(0xFF0F0F0F),
    surface: const Color(0xFF1A1A1A),
  );

  static final ThemeData deepSea = _baseTheme(
    primary: const Color(0xFF0077FF),
    background: const Color(0xFF010C13),
    surface: const Color(0xFF05151F),
  );

  static final ThemeData deepEmerald = _baseTheme(
    primary: const Color(0xFF2ECC71),
    background: const Color(0xFF0A120D),
    surface: const Color(0xFF141F17),
  );

  static final ThemeData royalAmethyst = _baseTheme(
    primary: const Color(0xFF9B59B6),
    background: const Color(0xFF0F0A12),
    surface: const Color(0xFF1C1421),
  );

  static ThemeData _baseTheme({required Color primary, required Color background, required Color surface}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.compact,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary.withOpacity(0.8),
        surface: surface,
        background: background,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, color: primary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 2, color: primary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
      ),
    );
  }
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

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) => ThemeNotifier());

final currentThemeProvider = Provider<ThemeData>((ref) {
  final type = ref.watch(themeProvider);
  switch (type) {
    case AppThemeType.onyx: return AppTheme.onyxGold;
    case AppThemeType.cyberpunk: return AppTheme.cyberPunk;
    case AppThemeType.toxic: return AppTheme.toxicNight;
    case AppThemeType.sea: return AppTheme.deepSea;
    case AppThemeType.emerald: return AppTheme.deepEmerald;
    case AppThemeType.amethyst: return AppTheme.royalAmethyst;
  }
});
