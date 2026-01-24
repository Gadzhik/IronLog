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
        title: const Text('Прогресс'),
        leading: _selectedExercise != null 
          ? IconButton(
              icon: const Icon(LucideIcons.chevronLeft), 
              onPressed: () => setState(() => _selectedExercise = null)
            ) 
          : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _selectedExercise == null 
          ? exercisesAsync.when(
              data: (exercises) => _ExerciseListView(
                exercises: exercises, 
                onSelect: (e) => setState(() => _selectedExercise = e)
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            )
          : _ExerciseDetailView(exercise: _selectedExercise!),
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
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск упражнения...',
              prefixIcon: Icon(LucideIcons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      cat, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                      )
                    ),
                  ),
                  ...items.map((e) => ListTile(
                    leading: const Icon(LucideIcons.dumbbell, size: 20),
                    title: Text(e.name),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () => widget.onSelect(e),
                  )),
                  const Divider(indent: 16, endIndent: 16, height: 1),
                ],
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
  const _ExerciseDetailView({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name, 
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
          ),
          Text(exercise.category, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 24),
          _ChartSection(exercise: exercise),
          const SizedBox(height: 24),
          // History list could go here if needed...
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
        if (data.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Нет данных для прогресса'),
        ));

        data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));

        return Column(
          children: [
            SizedBox(
              height: 300,
              child: _AnimatedLineChart(data: data),
            ),
            const SizedBox(height: 16),
            const Text('Максимальный вес по датам', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Text('Error: $err'),
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
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
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble() * _animation.value);
        }).toList();

        double maxY = (widget.data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b)) * 1.2;
        if (maxY == 0) maxY = 10;

        String format(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.05)),
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
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(DateFormat('d.MM').format(widget.data[i]['date']), style: const TextStyle(fontSize: 10)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (val, meta) => Text(format(val), style: const TextStyle(fontSize: 10)),
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
                color: Theme.of(context).colorScheme.primary,
                barWidth: 4,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                    radius: 4, 
                    color: Theme.of(context).scaffoldBackgroundColor, 
                    strokeColor: Theme.of(context).colorScheme.primary, 
                    strokeWidth: 2
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary.withOpacity(0.2), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 0),
        );
      },
    );
  }
}
