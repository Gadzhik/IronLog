import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/providers.dart';
import 'package:intl/intl.dart';

// Feature: Advanced filtering inputs
class StatsFilter {
  final int exerciseId;
  final Duration? range; // null = all time
  
  const StatsFilter(this.exerciseId, this.range);
  
  @override
  bool operator ==(Object other) => other is StatsFilter && 
      other.exerciseId == exerciseId && 
      other.range == range;
      
  @override
  int get hashCode => Object.hash(exerciseId, range);
}

// Bug Fix: Loading Loop 
// Ensure filter class overrides ==/hashCode so family provider doesn't recompute on same values
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
  
  // Feature: Compact Filter options
  final Map<String, Duration?> _ranges = {
    '1 день': const Duration(days: 1),
    '3 дня': const Duration(days: 3),
    'Неделя': const Duration(days: 7),
  };
  String? _selectedRangeKey; // Null means "All" / Reset

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) return const Text('Нет упражнений');
                return DropdownButtonFormField<Exercise>(
                  value: _selectedExercise,
                  hint: const Text('Выберите упражнение'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Упражнение',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: exercises.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedExercise = val;
                    });
                  },
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
                // Reset Button
                IconButton(
                  onPressed: () {
                     setState(() {
                       _selectedRangeKey = null;
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
        
        // Feature: Trend Line visual logic
        // We use spots as usual. The line itself demonstrates the trend.
        final spots = data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble());
        }).toList();

        double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
        double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        
        // Add more buffer for Y axis
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
                         // Feature: Clarity - show fewer labels but larger
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
                  isCurved: false, // Feature: Clear trend logic usually prefers straight lines or very slight curve
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
