import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
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

    return MaterialApp(
      title: 'IronLog',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Container(
            key: ValueKey(themeType),
            child: child,
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
