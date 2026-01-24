import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/providers.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 

class StatsFilter {
  final int exerciseId;
  final Duration? range; 
  
  const StatsFilter(this.exerciseId, this.range);
  
  @override
  bool operator ==(Object other) => other is StatsFilter && 
      other.exerciseId == exerciseId && 
      other.range == range;
      
  @override
  int get hashCode => Object.hash(exerciseId, range);
}

final maxWeightHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, StatsFilter>((ref, filter) async {
  final service = ref.read(isarServiceProvider);
  DateTime? after;
  if (filter.range != null) {
    after = DateTime.now().subtract(filter.range!);
  }
  return service.getMaxWeightHistory(filter.exerciseId, after: after);
});

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Exercise? _selectedExercise;
  
  // Feature: Overhauled Filter options
  final Map<String, Duration?> _ranges = {
    'Неделя': const Duration(days: 7),
    'Месяц': const Duration(days: 30),
    'Полгода': const Duration(days: 180),
    'Все время': null,
  };
  String? _selectedRangeKey = 'Все время'; // Default to All Time

  void _showExercisePicker(List<Exercise> exercises) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) {
       return _ExercisePicker(exercises: exercises, onSelect: (e) {
         setState(() => _selectedExercise = e);
         Navigator.pop(context);
       });
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _selectedRangeKey != null ? _ranges[_selectedRangeKey] : null;
    final exercisesAsync = ref.watch(exercisesForRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              exercisesAsync.when(
                data: (exercises) {
                  if (exercises.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('Нет данных за этот период', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  
                  return InkWell(
                    onTap: () => _showExercisePicker(exercises),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedExercise?.name ?? 'Выберите упражнение', 
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: _selectedExercise == null ? Colors.grey : null
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
              ),
              const SizedBox(height: 16),
              
              // Feature: Compact Filtering + Reset
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _ranges.keys.map((key) {
                          final isSelected = _selectedRangeKey == key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(key),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRangeKey = selected ? key : null;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                       setState(() {
                         _selectedRangeKey = 'Все время';
                         _selectedExercise = null;
                       });
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Сбросить',
                  )
                ],
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                height: 350, // Fixed height for chart within scroll view
                child: _selectedExercise == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.show_chart, size: 48, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('Выберите упражнение для анализа', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _ChartWidget(
                        exerciseId: _selectedExercise!.id,
                        range: range,
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onSelect;
  const _ExercisePicker({required this.exercises, required this.onSelect});

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';
  
  @override
  Widget build(BuildContext context) {
      final filtered = widget.exercises.where((e) => 
         e.name.toLowerCase().contains(_query.toLowerCase()) || 
         e.category.toLowerCase().contains(_query.toLowerCase())
      ).toList();
      
      final grouped = groupBy(filtered, (e) => e.category);
      final keys = grouped.keys.toList()..sort();

      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) {
           return Container(
             color: Theme.of(context).scaffoldBackgroundColor,
             child: Column(
               children: [
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: TextField(
                     decoration: const InputDecoration(
                       hintText: 'Поиск...',
                       prefixIcon: Icon(Icons.search),
                     ),
                     onChanged: (val) => setState(() => _query = val),
                   ),
                 ),
                 Expanded(
                   child: ListView(
                     controller: controller,
                     children: keys.map((cat) {
                       return ExpansionTile(
                         title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                         initiallyExpanded: true, 
                         children: grouped[cat]!.map((e) => ListTile(
                           contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                           visualDensity: VisualDensity.compact,
                           title: Text(e.name),
                           onTap: () => widget.onSelect(e),
                         )).toList(),
                       );
                     }).toList(),
                   ),
                 )
               ],
             ),
           );
        }
      );
  }
}

class _ChartWidget extends ConsumerWidget {
  final int exerciseId;
  final Duration? range;
  
  const _ChartWidget({required this.exerciseId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = StatsFilter(exerciseId, range);
    final historyAsync = ref.watch(maxWeightHistoryProvider(filter));

    return historyAsync.when(
      data: (data) {
        if (data.isEmpty) return const Center(child: Text('Нет данных за этот период'));
        
        data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));
        
        final spots = data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble());
        }).toList();

        double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
        double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        
        double buffer = (maxY - minY) * 0.2;
        if (buffer == 0) buffer = 5;
        
        minY = (minY - buffer).clamp(0, double.infinity);
        maxY = maxY + buffer;

        // Formatter for weights to show as integers
        String formatWeight(double val) {
           if (val == val.toInt().toDouble()) return val.toInt().toString();
           return val.toStringAsFixed(1);
        }

        return Padding(
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.05), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Дата', style: TextStyle(fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1, 
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (index >= 0 && index < data.length) {
                         int step = (data.length / 4).ceil();
                         if (step < 1) step = 1;
                         if (index % step != 0 && index != data.length - 1) return const SizedBox.shrink();

                         final date = data[index]['date'] as DateTime;
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             DateFormat('d MMM').format(date),
                             style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                           ),
                         );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('Вес (кг)', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) => Text(
                      formatWeight(val), 
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)
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
                  isCurved: true, // Smother look for Soft UI
                  curveSmoothness: 0.3,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                     show: true,
                     getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                           radius: 5,
                           strokeWidth: 2,
                           color: Theme.of(context).colorScheme.surface,
                           strokeColor: Theme.of(context).colorScheme.primary,
                        );
                     }
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        Theme.of(context).colorScheme.primary.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                 touchTooltipData: LineTouchTooltipData(
                   getTooltipColor: (spot) => Theme.of(context).colorScheme.primaryContainer,
                   getTooltipItems: (spots) {
                     return spots.map((spot) {
                       final index = spot.x.toInt();
                       final date = data[index]['date'] as DateTime;
                       return LineTooltipItem(
                         '${formatWeight(spot.y)} кг\n${DateFormat('d MMMM').format(date)}',
                         TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                       );
                     }).toList();
                   }
                 ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Ошибка: $err')),
    );
  }
}
