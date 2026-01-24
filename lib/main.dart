import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/app_theme.dart';
import 'package:iron_log/ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const ProviderScope(child: IronLogApp()));
}

class IronLogApp extends ConsumerWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final themeData = ref.watch(currentThemeProvider);
    
    // Feature: Pre-trigger Isar init and monitor it
    final exercisesAsync = ref.watch(allExercisesProvider);

    return MaterialApp(
      title: 'IRONLOG',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      locale: const Locale('ru', 'RU'),
      home: exercisesAsync.when(
        data: (_) => const HomeScreen(),
        loading: () => const _LoadingScreen(),
        error: (err, stack) => _ErrorScreen(error: err.toString()),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 24),
            Text('ЗАГРУЗКА БАЗЫ ДАННЫХ...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 24),
            const Text('ОШИБКА ЗАПУСКА', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Restart logic (or just hope for the best on reload)
              }, 
              child: const Text('ПОПРОБОВАТЬ СНОВА')
            )
          ],
        ),
      ),
    );
  }
}
