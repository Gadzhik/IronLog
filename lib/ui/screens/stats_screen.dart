import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 

class StatsFilter {
  final int exerciseId;
  final ExerciseType type;
  const StatsFilter(this.exerciseId, this.type);
  
  @override
  bool operator ==(Object other) => other is StatsFilter && other.exerciseId == exerciseId && other.type == type;
  @override
  int get hashCode => Object.hash(exerciseId, type);
}

final exerciseHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, StatsFilter>((ref, filter) async {
  final service = ref.read(isarServiceProvider);
  return service.getExerciseHistory(filter.exerciseId, filter.type);
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
        title: Text(_selectedExercise == null ? 'ПРОГРЕСС' : 'АНАЛИТИКА'),
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
      e.category.toLowerCase().contains(_query.toLowerCase())
    ).toList();
    
    // Feature: Independent grouping and filtering logic
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
                  title: Text(cat!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                  initiallyExpanded: false, // Collapsed by default
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                  collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                  backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                  children: items.map((e) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                exercise.name.toUpperCase(), 
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1,
                )
              ),
            ),
          ),
          Text(
            exercise.type == ExerciseType.strength ? 'СИЛОВЫЕ / ВЕС' : 'ВЫНОСЛИВОСТЬ / ВРЕМЯ',
            style: TextStyle(color: Theme.of(context).hintColor, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _ChartSection(exercise: exercise),
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
    final historyAsync = ref.watch(exerciseHistoryProvider(StatsFilter(exercise.id, exercise.type)));

    return historyAsync.when(
      data: (data) {
        if (data.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Text('НЕТ ДАННЫХ ПО ЭТОМУ УПРАЖНЕНИЮ', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
        ));

        final isCardio = exercise.type == ExerciseType.cardio;
        final label = isCardio ? 'ОБЩЕЕ ВРЕМЯ (МИН)' : 'МАКС. ВЕС (КГ)';

        return Column(
          children: [
            Container(
              height: 350,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _HistoryChart(data: data, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('ОШИБКА: $err'),
    );
  }
}

class _HistoryChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final Color color;
  const _HistoryChart({required this.data, required this.color});

  @override
  State<_HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<_HistoryChart> with SingleTickerProviderStateMixin {
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
          return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble() * _animation.value);
        }).toList();

        double maxY = (widget.data.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b)) * 1.3;
        if (maxY == 0) maxY = 10;

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, m) {
                    int i = v.toInt();
                    if (i >= 0 && i < widget.data.length && (widget.data.length < 5 || i % (widget.data.length ~/ 3) == 0)) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(DateFormat('d.MM').format(widget.data[i]['date']), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                )
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
               touchTooltipData: LineTouchTooltipData(
                 getTooltipColor: (_) => Colors.grey[900]!,
                 getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) => LineTooltipItem('${s.y.toInt()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList();
                 }
               )
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: widget.color,
                barWidth: 5,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true, getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(radius: 4, color: Colors.black, strokeColor: widget.color, strokeWidth: 2)),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(colors: [widget.color.withOpacity(0.4), widget.color.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
