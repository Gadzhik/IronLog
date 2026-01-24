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
                  title: Text(cat!.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1)),
                  initiallyExpanded: false, // Requirement: Collapsed by default
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  children: items.map((e) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(e.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () => widget.onSelect(e),
                  )).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseDetailView extends ConsumerWidget {
  final Exercise exercise;
  const _ExerciseDetailView({required this.exercise, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(progressHistoryProvider(exercise.id));
    final metric = ref.watch(progressMetricProvider);
    final isCardio = exercise.type == ExerciseType.cardio;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name.toUpperCase(), 
            style: GoogleFonts.bebasNeue(fontSize: 28, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5)
          ),
          const SizedBox(height: 8),
          _MetricSelector(isCardio: isCardio),
          const SizedBox(height: 32),
          
          Container(
            height: 350,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: historyAsync.when(
              data: (data) => ProgressChartWidget(
                data: data, 
                themeColor: Theme.of(context).colorScheme.primary,
                metric: metric,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
            ),
          ),
          
          const SizedBox(height: 24),
          if (historyAsync.hasValue && historyAsync.value!.isNotEmpty)
            _LastSessionSummary(point: historyAsync.value!.last, isCardio: isCardio, metric: metric),
        ],
      ),
    );
  }
}

class _MetricSelector extends ConsumerWidget {
  final bool isCardio;
  const _MetricSelector({required this.isCardio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(progressMetricProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: isCardio ? [
          _chip(ref, ProgressMetric.cardioPace, 'ТЕМП (МИН/КМ)', metric),
          _chip(ref, ProgressMetric.cardioVolume, 'ДИСТАНЦИЯ (КМ)', metric),
        ] : [
          _chip(ref, ProgressMetric.strength1RM, 'EST. 1RM (КГ)', metric),
          _chip(ref, ProgressMetric.strengthVolume, 'ОБЪЕМ (КГ)', metric),
        ],
      ),
    );
  }

  Widget _chip(WidgetRef ref, ProgressMetric m, String label, ProgressMetric current) {
    final selected = m == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: selected ? Colors.black : Colors.white70)),
        selected: selected,
        onSelected: (val) {
          if (val) {
            HapticFeedback.lightImpact();
            ref.read(progressMetricProvider.notifier).state = m;
          }
        },
        selectedColor: ref.read(currentThemeProvider).colorScheme.primary,
      ),
    );
  }
}

class _LastSessionSummary extends StatelessWidget {
  final ProgressDataPoint point;
  final bool isCardio;
  final ProgressMetric metric;

  const _LastSessionSummary({required this.point, required this.isCardio, required this.metric});

  @override
  Widget build(BuildContext context) {
    String label = 'РЕЗУЛЬТАТ';
    String value = point.value.toStringAsFixed(1);
    
    if (metric == ProgressMetric.strength1RM) label = 'РАСЧЕТНЫЙ 1RM';
    if (metric == ProgressMetric.strengthVolume) label = 'ОБЩИЙ ОБЪЕМ';
    if (metric == ProgressMetric.cardioPace) label = 'ТЕМП СЕССИИ';
    if (metric == ProgressMetric.cardioVolume) label = 'ДИСТАНЦИЯ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ИЗМЕНЕНИЕ', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                '${point.percentChange >= 0 ? '+' : ''}${point.percentChange.toStringAsFixed(1)}%',
                style: GoogleFonts.bebasNeue(
                  fontSize: 24, 
                  color: point.percentChange >= 0 ? Colors.greenAccent : Colors.redAccent,
                  letterSpacing: 1
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
