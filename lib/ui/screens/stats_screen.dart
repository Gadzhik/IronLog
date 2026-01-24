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
  
  StatsFilter(this.exerciseId, this.range);
}

// Updated provider to accept filter object or just exerciseId
// Simplified: Just pass args separately or simpler family. 
// Using a simpler approach: Provider that returns all max weights, filter in UI or Service.
// Let's stick to service filtering for performance if data grows.
// Let's modify IsarService to accept "after" date.

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
  
  // Feature: Time Range Filter
  // Options: 1 Week, 1 Month, 3 Months, 1 Year, All
  final Map<String, Duration?> _ranges = {
    'Неделя': const Duration(days: 7),
    'Месяц': const Duration(days: 30),
    '3 Месяца': const Duration(days: 90),
    'Год': const Duration(days: 365),
    'Всё время': null,
  };
  String _selectedRangeKey = 'Всё время';

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Exercise Selector
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
            
            // Feature: Time Range Filter Chips
            SingleChildScrollView(
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
                        if (selected) {
                          setState(() {
                            _selectedRangeKey = key;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
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
                      range: _ranges[_selectedRangeKey],
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
        
        // Sort by date just in case
        data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));
        
        // Map to spots (index as x) or use timestamp as X?
        // Index is easier for equal spacing, but timestamp is better for time gaps.
        // Let's use index for simplicity in MVP, but improved tooltip showing date.
        
        final spots = data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble());
        }).toList();

        // Calculate min/max Y for better scale
        double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
        double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        minY = (minY - 5).clamp(0, double.infinity);
        maxY = maxY + 5;

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
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1, 
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (index >= 0 && index < data.length) {
                         // Feature: Better readability logic
                         // Show max 5-7 labels on X axis
                         int step = (data.length / 5).ceil();
                         if (index % step != 0 && index != data.length - 1) return const SizedBox.shrink();

                         final date = data[index]['date'] as DateTime;
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             DateFormat('dd.MM').format(date),
                             style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(), 
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)
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
                  curveSmoothness: 0.2, // Less curve, more precise
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                   getTooltipColor: (spot) => const Color(0xFF2C2C2E),
                   getTooltipItems: (spots) {
                     return spots.map((spot) {
                       final index = spot.x.toInt();
                       final date = data[index]['date'] as DateTime;
                       return LineTooltipItem(
                         '${spot.y} кг\n${DateFormat('d MMMM').format(date)}',
                         const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
