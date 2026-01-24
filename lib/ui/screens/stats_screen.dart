import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 

class StatsFilter {
  final int exerciseId;
  const StatsFilter(this.exerciseId);
  
  @override
  bool operator ==(Object other) => other is StatsFilter && other.exerciseId == exerciseId;
  @override
  int get hashCode => exerciseId.hashCode;
}

final maxWeightHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, StatsFilter>((ref, filter) async {
  final service = ref.read(isarServiceProvider);
  return service.getMaxWeightHistory(filter.exerciseId);
});

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
        title: Text('Прогресс', style: Theme.of(context).appBarTheme.titleTextStyle),
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
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
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
      e.category.toLowerCase().contains(_query.toLowerCase())
    ).toList();
    
    final grouped = groupBy(filtered, (e) => e.category);
    final keys = grouped.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
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
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final cat = keys[index];
              final items = grouped[cat]!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ExpansionTile(
                    backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                    collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                    initiallyExpanded: false, // Requirement: Collapsed by default
                    leading: Icon(_getCategoryIcon(cat), size: 20, color: Theme.of(context).colorScheme.primary),
                    title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    children: items.map((e) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(e.name, style: const TextStyle(fontSize: 14)),
                      trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                      onTap: () => widget.onSelect(e),
                    )).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'грудь': return LucideIcons.circleDot;
      case 'спина': return LucideIcons.layers;
      case 'ноги': return LucideIcons.footprints;
      case 'плечи': return LucideIcons.moveUp;
      case 'руки': return LucideIcons.dumbbell;
      case 'кардио': return LucideIcons.heartPulse;
      default: return LucideIcons.dumbbell;
    }
  }
}

class _ExerciseDetailView extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseDetailView({required this.exercise, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'ex_${exercise.id}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                exercise.name, 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onBackground
                )
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            exercise.category.toUpperCase(), 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary, 
              fontWeight: FontWeight.bold, 
              fontSize: 12, 
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 32),
          _ChartSection(exercise: exercise),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ChartSection extends ConsumerWidget {
  final Exercise exercise;
  const _ChartSection({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(maxWeightHistoryProvider(StatsFilter(exercise.id)));

    return historyAsync.when(
      data: (data) {
        if (data.isEmpty) return Center(
          child: Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              children: [
                Icon(LucideIcons.barChart2, size: 48, color: Theme.of(context).dividerColor),
                const SizedBox(height: 16),
                const Text('Нет данных для прогресса', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );

        data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: Column(
            children: [
              SizedBox(
                height: 320,
                child: _AnimatedLineChart(data: data),
              ),
              const SizedBox(height: 20),
              Text(
                'Прогресс максимального веса', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor)
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Text('Ошибка: $err'),
    );
  }
}

class _AnimatedLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const _AnimatedLineChart({required this.data});

  @override
  State<_AnimatedLineChart> createState() => _AnimatedLineChartState();
}

class _AnimatedLineChartState extends State<_AnimatedLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutExpo);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final spots = widget.data.asMap().entries.map((e) {
          // Multiply weight by animation value for draw-in effect
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble() * _animation.value);
        }).toList();

        double maxY = (widget.data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b)) * 1.25;
        if (maxY == 0) maxY = 10;

        String format(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(
                color: Theme.of(context).dividerColor.withOpacity(0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (val, meta) {
                    final i = val.toInt();
                    if (i >= 0 && i < widget.data.length && (widget.data.length < 5 || i % (widget.data.length ~/ 4) == 0)) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          DateFormat('d.MM').format(widget.data[i]['date']), 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor)
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (val, meta) => Text(
                    format(val), 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor)
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.4,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 6,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                    radius: 5, 
                    color: Theme.of(context).scaffoldBackgroundColor, 
                    strokeColor: Theme.of(context).colorScheme.primary, 
                    strokeWidth: 3
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3), 
                      Theme.of(context).colorScheme.primary.withOpacity(0.0)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Theme.of(context).colorScheme.surface,
                tooltipRoundedRadius: 12,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((s) {
                    return LineTooltipItem(
                      '${format(s.y / _animation.value)} кг',
                      TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800),
                    );
                  }).toList();
                }
              ),
            ),
          ),
          duration: const Duration(milliseconds: 0),
        );
      },
    );
  }
}
