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
  
  // Feature: Compact Filter options - Added 'Месяц' as requested in prompt.
  final Map<String, Duration?> _ranges = {
    '1 день': const Duration(days: 1),
    '3 дня': const Duration(days: 3),
    'Неделя': const Duration(days: 7),
    'Месяц': const Duration(days: 30),
  };
  String? _selectedRangeKey; 

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
    // Logic: If range is selected, show only relevant exercises. Else show all.
    final range = _selectedRangeKey != null ? _ranges[_selectedRangeKey] : null;
    final exercisesAsync = ref.watch(exercisesForRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            exercisesAsync.when(
              data: (exercises) {
                // If selected exercise is no longer in the list (e.g. range changed), we might keep it or clear it.
                // Requirement: "Independent Filters". 
                // Suggestion: Ensure the dropdown shows exercises valid for the range. 
                // If user selected "Bench Press" and "1 Day", but Bench Press wasn't done today, 
                // the chart will simply show "No Data" which is correct behavior for independent filters?
                // Or should the dropdown be filtered?
                // "If I select '1 day', the screen must show ALL exercises performed on that day."
                // This implies the picker list updates.
                
                if (exercises.isEmpty) return const Text('Нет данных за этот период');
                
                // If currently selected exercise is not in the new filtered list?
                // Independent filters usually means one doesn't clear the other, but the RESULT combines both.
                // But the picker itself: "Scenario: If I select '1 day', the screen must show ALL exercises performed on that day."
                // This likely means the *available* exercises to pick from.
                
                return InkWell(
                  onTap: () => _showExercisePicker(exercises),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedExercise?.name ?? 'Выберите упражнение', 
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _selectedExercise == null ? Colors.grey : null
                          )
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error loading exercises: $err'),
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
                // Feature: Global Reset
                IconButton(
                  onPressed: () {
                     setState(() {
                       _selectedRangeKey = null;
                       _selectedExercise = null;
                     });
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Сбросить',
                )
              ],
            ),
            
            const SizedBox(height: 24),
            Expanded(
              child: _selectedExercise == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 48, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          const Text('Выберите упражнение', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _ChartWidget(
                      exerciseId: _selectedExercise!.id,
                      range: _selectedRangeKey != null ? _ranges[_selectedRangeKey] : null,
                    ),
            ),
          ],
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

        return Padding(
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Дата', style: TextStyle(fontSize: 12)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1, 
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (index >= 0 && index < data.length) {
                         int step = (data.length / 4).ceil();
                         if (index % step != 0 && index != data.length - 1) return const SizedBox.shrink();

                         final date = data[index]['date'] as DateTime;
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             DateFormat('d MMM').format(date),
                             style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                           ),
                         );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Вес (кг)', style: TextStyle(fontSize: 12)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(), 
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)
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
                  isCurved: false,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                     show: true,
                     getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                           radius: 4,
                           strokeWidth: 2,
                           color: Theme.of(context).colorScheme.surface,
                           strokeColor: Theme.of(context).colorScheme.primary,
                        );
                     }
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.25),
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
                   getTooltipColor: (spot) => const Color(0xFF2C2C2E),
                   getTooltipItems: (spots) {
                     return spots.map((spot) {
                       final index = spot.x.toInt();
                       final date = data[index]['date'] as DateTime;
                       return LineTooltipItem(
                         '${spot.y} кг\n${DateFormat('d MMMM').format(date)}',
                         const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
