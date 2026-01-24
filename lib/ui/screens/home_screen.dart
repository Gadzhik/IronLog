import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/active_session_screen.dart';
import 'package:iron_log/ui/screens/stats_screen.dart';
import 'package:iron_log/ui/screens/workout_detail_screen.dart';
import 'package:flutter/services.dart';

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
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Мои тренировки',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Прогресс',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          ref.read(activeSessionProvider.notifier).startSession();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
          );
        },
        label: const Text('Новая тренировка'),
        icon: const Icon(Icons.add),
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
        title: const Text('Мои тренировки'),
        actions: [
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
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                            Navigator.pop(context);
                          },
                          child: const Text('Copy'),
                        )
                      ],
                    ));
                 }
              } else if (val == 'clear') {
                 showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Удалить всё?'),
                    content: const Text('Это действие нельзя отменить.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                      TextButton(onPressed: () async {
                         await ref.read(isarServiceProvider).clearAllData();
                         if (context.mounted) Navigator.pop(context);
                      }, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                    ],
                 ));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Экспорт JSON')),
              const PopupMenuItem(value: 'clear', child: Text('Очистить всё', style: TextStyle(color: Colors.red))),
            ],
          ),
          PopupMenuButton<AppThemeType>(
            icon: const Icon(Icons.color_lens),
            onSelected: (val) {
               ref.read(themeProvider.notifier).setTheme(val);
            },
            itemBuilder: (context) => [
               const PopupMenuItem(value: AppThemeType.midnight, child: Text('Midnight')),
               const PopupMenuItem(value: AppThemeType.iron, child: Text('Iron')),
               const PopupMenuItem(value: AppThemeType.toxic, child: Text('Toxic')),
            ],
          )
        ],
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history, size: 64, color: Colors.grey[800]),
                   const SizedBox(height: 16),
                   const Text('Нет тренировок', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              // Feature: Swipe-to-Right for details
              return Dismissible(
                key: ValueKey(session.id),
                // Allow swipe both ways logic? 
                // Right (startToEnd): Details
                // Left (endToStart): Delete
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  color: Colors.blue,
                  child: const Icon(Icons.visibility, color: Colors.white),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                     // Navigate to details
                     Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)));
                     return false; // Don't dismiss
                  } else {
                     return true; // Proceed to onDismissed for delete
                  }
                },
                onDismissed: (direction) {
                  if (direction == DismissDirection.endToStart) {
                    ref.read(isarServiceProvider).deleteWorkout(session.id);
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)));
                  },
                  child: WorkoutHistoryCard(session: session),
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
    final dateStr = DateFormat('d MMMM yyyy, HH:mm', 'ru').format(session.startTime);
    final duration = session.endTime != null 
        ? session.endTime!.difference(session.startTime).inMinutes 
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                       if (session.name != null && session.name!.isNotEmpty)
                         Text(
                            session.name!, 
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                         ),
                       Text(
                        dateStr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (duration > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$duration мин',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${session.entries.length} упражнений',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: session.entries.take(3).map((e) => Chip(
                label: Text(e.exerciseName ?? 'Упражнение'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.black26,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
