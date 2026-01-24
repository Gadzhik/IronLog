import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/app_theme.dart';
import 'package:iron_log/ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  
  // Initialize Isar early?
  // Riverpod provider initializes it lazily. Ideally we wait for it.
  // But for now, lazy is fine, use AsyncValue in UI.
  
  runApp(const ProviderScope(child: IronLogApp()));
}

class IronLogApp extends ConsumerWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Open DB helper
    ref.watch(isarServiceProvider); // Trigger init

    return MaterialApp(
      title: 'IronLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ru', 'RU'),
      home: const HomeScreen(),
    );
  }
}
