import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  final Map<String, Duration?> _ranges = {
    'Неделя': const Duration(days: 7),
    'Месяц': const Duration(days: 30),
    'Все время': null,
  };
  String? _selectedRangeKey = 'Все время';

  void _showExercisePicker(List<Exercise> exercises) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
       return _ExercisePicker(exercises: exercises, onSelect: (e) {
         HapticFeedback.selectionClick();
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
      appBar: AppBar(
        title: const Text('Прогресс', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              exercisesAsync.when(
                data: (exercises) {
                  if (exercises.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: Theme.of(context).disabledColor),
                            const SizedBox(height: 16),
                            const Text('Нет данных за этот период', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return InkWell(
                    onTap: () => _showExercisePicker(exercises),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedExercise?.name ?? 'Выберите упражнение', 
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: _selectedExercise == null ? Colors.grey : null,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Ошибка: $err'),
              ),
              const SizedBox(height: 16),
              
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
                            HapticFeedback.lightImpact();
                            setState(() => _selectedRangeKey = key);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (_selectedExercise != null) ...[
                Text(
                  'Максимальный вес',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              
              SizedBox(
                height: 320,
                child: _selectedExercise == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            const Text('Выберите упражнение для анализа', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _AnimatedChart(
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

class _AnimatedChart extends StatefulWidget {
  final int exerciseId;
  final Duration? range;
  const _AnimatedChart({required this.exerciseId, required this.range});

  @override
  State<_AnimatedChart> createState() => _AnimatedChartState();
}

class _AnimatedChartState extends State<_AnimatedChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exerciseId != oldWidget.exerciseId || widget.range != oldWidget.range) {
      _controller.reset();
      _controller.forward();
    }
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
        return _ChartWidget(
          exerciseId: widget.exerciseId,
          range: widget.range,
          animationValue: _animation.value,
        );
      },
    );
  }
}

class _ChartWidget extends ConsumerWidget {
  final int exerciseId;
  final Duration? range;
  final double animationValue;
  
  const _ChartWidget({required this.exerciseId, required this.range, required this.animationValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = StatsFilter(exerciseId, range);
    final historyAsync = ref.watch(maxWeightHistoryProvider(filter));

    return historyAsync.when(
      data: (data) {
        if (data.isEmpty) return const Center(child: Text('Нет данных за этот период'));
        
        data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));
        
        final spots = data.asMap().entries.map((e) {
          // Multiply Y by animationValue for draw-in effect
          return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble() * animationValue);
        }).toList();

        double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
        double maxY = (data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b)) * 1.1;
        
        if (minY == maxY) {
          minY = 0;
          maxY = (maxY == 0) ? 10 : maxY * 1.5;
        }

        String formatWeight(double val) {
           if (val == val.toInt().toDouble()) return val.toInt().toString();
           return val.toStringAsFixed(1);
        }

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY / 5).clamp(1, double.infinity),
              getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.05), strokeWidth: 1),
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
                       int step = (data.length / 4).ceil();
                       if (step < 1) step = 1;
                       if (index % step != 0 && index != data.length - 1) return const SizedBox.shrink();

                       final date = data[index]['date'] as DateTime;
                       return Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Text(
                           DateFormat('d MMM').format(date),
                           style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor, fontWeight: FontWeight.bold),
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
                isCurved: true,
                curveSmoothness: 0.35,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                   show: true,
                   getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                         radius: 4,
                         strokeWidth: 2.5,
                         color: Theme.of(context).scaffoldBackgroundColor,
                         strokeColor: Theme.of(context).colorScheme.primary,
                      );
                   }
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                 getTooltipColor: (spot) => Theme.of(context).colorScheme.surface,
                 getTooltipItems: (spots) {
                   return spots.map((spot) {
                     final index = spot.x.toInt();
                     final date = data[index]['date'] as DateTime;
                     return LineTooltipItem(
                       '${formatWeight(spot.y / animationValue)} кг\n',
                       TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                       children: [
                         TextSpan(
                           text: DateFormat('d MMMM').format(date),
                           style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.normal, fontSize: 12),
                         )
                       ]
                     );
                   }).toList();
                 }
               ),
            ),
          ),
          duration: const Duration(milliseconds: 0), // Turned off fl_chart internal animation to use AnimatedBuilder
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Ошибка: $err')),
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
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) {
           return Container(
             padding: const EdgeInsets.only(top: 8),
             child: Column(
               children: [
                 Container(
                   width: 40,
                   height: 4,
                   margin: const EdgeInsets.only(bottom: 16),
                   decoration: BoxDecoration(
                     color: Colors.grey[300],
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
                   child: TextField(
                     decoration: const InputDecoration(
                       hintText: 'Поиск...',
                       prefixIcon: Icon(Icons.search_rounded),
                     ),
                     onChanged: (val) => setState(() => _query = val),
                   ),
                 ),
                 const SizedBox(height: 8),
                 Expanded(
                   child: ListView(
                     controller: controller,
                     children: keys.map((cat) {
                       return ExpansionTile(
                         title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                         initiallyExpanded: filtered.length < 20, 
                         children: grouped[cat]!.map((e) => ListTile(
                           contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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
