import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/progress_provider.dart';
import 'package:iron_log/ui/app_theme.dart';
import 'package:iron_log/ui/widgets/progress_chart_widget.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Exercise? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedExercise == null ? 'АНАЛИТИКА' : 'ПРОГРЕСС', 
          style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 2)
        ),
        leading: _selectedExercise != null 
          ? IconButton(
              icon: const Icon(LucideIcons.chevronLeft), 
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedExercise = null);
              }
            ) 
          : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _selectedExercise == null 
          ? exercisesAsync.when(
              data: (exercises) => _ExerciseListView(
                exercises: exercises, 
                onSelect: (e) {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedExercise = e);
                }
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Ошибка: $err')),
            )
          : _ExerciseDetailView(exercise: _selectedExercise!, key: ValueKey(_selectedExercise!.id)),
      ),
    );
  }
}

class _ExerciseListView extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onSelect;
  const _ExerciseListView({required this.exercises, required this.onSelect});

  @override
  State<_ExerciseListView> createState() => _ExerciseListViewState();
}

class _ExerciseListViewState extends State<_ExerciseListView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((e) => 
      e.name.toLowerCase().contains(_query.toLowerCase()) || 
      (e.category?.toLowerCase().contains(_query.toLowerCase()) ?? false)
    ).toList();
    
    final grouped = groupBy(filtered, (e) => (e.category == null || e.category!.isEmpty) ? 'ПРОЧЕЕ' : e.category);
    final keys = grouped.keys.toList()..sort((a,b) {
       if (a == 'ПРОЧЕЕ') return 1;
       if (b == 'ПРОЧЕЕ') return -1;
       return a!.compareTo(b!);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск упражнения...',
              prefixIcon: Icon(LucideIcons.search, size: 20),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final cat = keys[index];
              final items = grouped[cat]!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  title: Text(cat!.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.5)),
                  initiallyExpanded: false, // Collapsed by default
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: items.map((e) => _ExerciseTile(exercise: e, onTap: () => widget.onSelect(e))).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(progressStreamProvider(exercise.id));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(exercise.name.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
      trailing: historyAsync.when(
        data: (data) {
          if (data.isEmpty || data.length < 2) return const Icon(LucideIcons.chevronRight, size: 16);
          final bool growth = data.last.isGrowth;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                growth ? LucideIcons.trendingUp : LucideIcons.trendingDown, 
                size: 16, 
                color: growth ? Colors.greenAccent : Colors.redAccent
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 16),
            ],
          );
        },
        loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_,__) => const Icon(LucideIcons.chevronRight, size: 16),
      ),
      onTap: onTap,
    );
  }
}

class _ExerciseDetailView extends ConsumerWidget {
  final Exercise exercise;
  const _ExerciseDetailView({required this.exercise, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(progressStreamProvider(exercise.id));
    final metric = ref.watch(progressMetricProvider);
    final isCardio = exercise.type == ExerciseType.cardio;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name.toUpperCase(), 
                  style: GoogleFonts.bebasNeue(fontSize: 32, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5)
                ),
                Text(
                  exercise.category?.toUpperCase() ?? 'ПРОЧЕЕ',
                  style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Container(
            height: 350,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: historyAsync.when(
              data: (data) => ProgressChartWidget(
                data: data, 
                themeColor: Theme.of(context).colorScheme.primary,
                isCardio: isCardio,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Ошибка: $err')),
            ),
          ),
          
          const SizedBox(height: 24),
          historyAsync.when(
            data: (data) => data.isNotEmpty 
              ? _LatestMetricCard(point: data.last, isCardio: isCardio)
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_,__) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LatestMetricCard extends StatelessWidget {
  final ProgressDataPoint point;
  final bool isCardio;

  const _LatestMetricCard({required this.point, required this.isCardio});

  @override
  Widget build(BuildContext context) {
    final color = point.isGrowth ? Colors.greenAccent : Colors.redAccent;
    final icon = point.isGrowth ? LucideIcons.trendingUp : LucideIcons.trendingDown;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ПОСЛЕДНИЙ РЕЗУЛЬТАТ', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '${point.value.toInt()} ${isCardio ? 'КМ' : 'КГ'}', 
                  style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 1)
                ),
              ],
            ),
          ),
          if (point.percentChange != 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ДИНАМИКА', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '${point.percentChange >= 0 ? '+' : ''}${point.percentChange.toInt()}%',
                  style: GoogleFonts.bebasNeue(fontSize: 32, color: color, letterSpacing: 1),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
