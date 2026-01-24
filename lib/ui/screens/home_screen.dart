import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/active_session_screen.dart';
import 'package:iron_log/ui/screens/stats_screen.dart';
import 'package:iron_log/ui/screens/workout_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iron_log/ui/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HistoryTab(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.list),
            selectedIcon: Icon(LucideIcons.list, color: Colors.white),
            label: 'Тренировки',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.trendingUp),
            selectedIcon: Icon(LucideIcons.trendingUp, color: Colors.white),
            label: 'Прогресс',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(activeSessionProvider.notifier).startSession();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionScreen()));
        },
        label: const Text('Новая тренировка'),
        icon: const Icon(LucideIcons.plus),
      ) : null,
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IronLog'),
        actions: [
          PopupMenuButton<AppThemeType>(
            icon: const Icon(LucideIcons.palette),
            onSelected: (val) {
               HapticFeedback.lightImpact();
               ref.read(themeProvider.notifier).setTheme(val);
            },
            itemBuilder: (context) => [
               const PopupMenuItem(value: AppThemeType.light, child: Text('Комфорт')),
               const PopupMenuItem(value: AppThemeType.toxic, child: Text('Токсик')),
               const PopupMenuItem(value: AppThemeType.midnight, child: Text('Midnight')),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'export') {
                 final json = await ref.read(isarServiceProvider).exportData();
                 if (context.mounted) {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      title: const Text('Backup JSON'),
                      content: SelectableText(json),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: json));
                            Navigator.pop(context);
                          },
                          child: const Text('Копировать'),
                        )
                      ],
                    ));
                 }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Экспорт')),
            ],
          ),
        ],
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(LucideIcons.history, size: 64, color: Theme.of(context).dividerColor),
                   const SizedBox(height: 16),
                   const Text('Нет тренировок', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Dismissible(
                key: ValueKey(session.id),
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  color: Colors.blue.withOpacity(0.2),
                  child: const Icon(LucideIcons.eye, color: Colors.blue),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red.withOpacity(0.2),
                  child: const Icon(LucideIcons.trash2, color: Colors.red),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)));
                     return false;
                  } else {
                     return true; 
                  }
                },
                onDismissed: (_) {
                  HapticFeedback.mediumImpact();
                  ref.read(isarServiceProvider).deleteWorkout(session.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session))),
                    child: WorkoutHistoryCard(session: session),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Ошибка: $err')),
      ),
    );
  }
}

class WorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession session;
  const WorkoutHistoryCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMMM, HH:mm', 'ru').format(session.startTime);
    final duration = session.endTime != null 
        ? session.endTime!.difference(session.startTime).inMinutes 
        : 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                         session.name?.isNotEmpty == true ? session.name! : 'Тренировка', 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                       ),
                       Text(dateStr, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                    ],
                  ),
                ),
                if (duration > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text('$duration мин', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: session.entries.take(3).map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                child: Text(e.exerciseName ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
