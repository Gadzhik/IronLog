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
import 'package:google_fonts/google_fonts.dart';

bool isMatch(String input, String target) {
  final cleanInput = input.replaceAll('"', '').replaceAll("'", "").trim().toLowerCase();
  final cleanTarget = target.toLowerCase();
  return cleanInput == cleanTarget;
}

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
            label: 'Тренировки',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.trendingUp),
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
        label: const Text('НОВАЯ ТРЕНИРОВКА'),
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
        title: Text('IRONLOG', style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 2)),
        actions: [
          PopupMenuButton<AppThemeType>(
            icon: const Icon(LucideIcons.palette),
            onSelected: (val) {
               HapticFeedback.lightImpact();
               ref.read(themeProvider.notifier).setTheme(val);
            },
            itemBuilder: (context) => [
               const PopupMenuItem(value: AppThemeType.onyx, child: Text('Onyx & Gold')),
               const PopupMenuItem(value: AppThemeType.cyberpunk, child: Text('Cyber Punk')),
               const PopupMenuItem(value: AppThemeType.toxic, child: Text('Toxic Night')),
               const PopupMenuItem(value: AppThemeType.sea, child: Text('Deep Sea')),
               const PopupMenuItem(value: AppThemeType.emerald, child: Text('Deep Emerald')),
               const PopupMenuItem(value: AppThemeType.amethyst, child: Text('Royal Amethyst')),
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
                   Icon(LucideIcons.dumbbell, size: 64, color: Theme.of(context).disabledColor),
                   const SizedBox(height: 16),
                   const Text('НЕТ ТРЕНИРОВОК', style: TextStyle(color: Colors.grey, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey(session.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Theme.of(context).colorScheme.primary.withOpacity(0.2), Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(LucideIcons.eye, color: Theme.of(context).colorScheme.primary),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.red.withOpacity(0.2)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(LucideIcons.trash2, color: Colors.red),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)));
                      return false; // Prevent dismissal for right swipe
                    } else {
                      return true;
                    }
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      HapticFeedback.mediumImpact();
                      ref.read(isarServiceProvider).deleteWorkout(session.id);
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)));
                    },
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  session.name?.toUpperCase() ?? 'ТРЕНИРОВКА', 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
                ),
              ),
              if (duration > 0)
                Text('${duration.toInt()} МИН', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(dateStr, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: session.entries.take(3).map((e) {
              final rawName = e.exerciseName ?? '';
              final displayName = rawName.replaceAll('"', '').replaceAll("'", "").trim();
              
              // Nuclear Unit Fix for "Планка"
              final unit = rawName.toLowerCase().contains("планка") ? "мин" : "повт";

              String details = '';
              if (e.sets.isNotEmpty) {
                 final set = e.sets.lastWhere((s) => s.isCompleted, orElse: () => e.sets.last);
                 
                 final bool isBodyweight = isMatch(rawName, "книжка") || 
                                          isMatch(rawName, "планка") || 
                                          isMatch(rawName, "подъем ног в висе") || 
                                          isMatch(rawName, "приседания без веса") || 
                                          isMatch(rawName, "отжимания от пола") ||
                                          isMatch(rawName, "гиперэкстензия") ||
                                          isMatch(rawName, "подтягивания") ||
                                          isMatch(rawName, "отжимания на брусьях") ||
                                          isMatch(rawName, "отжимания от скамьи") ||
                                          isMatch(rawName, "скручивания");

                 if (isBodyweight) {
                   details = "${set.reps} $unit";
                 } else {
                   details = "${set.weight} кг x ${set.reps}";
                 }
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                child: Text('${displayName.toUpperCase()} $details', style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
