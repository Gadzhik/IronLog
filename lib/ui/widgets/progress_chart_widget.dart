import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/progress_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iron_log/data/models/exercise.dart';

class ProgressChartWidget extends StatelessWidget {
  final List<ProgressDataPoint> data;
  final Color themeColor;
  final ExerciseType type;
  final String exerciseName;

  const ProgressChartWidget({
    super.key,
    required this.data,
    required this.themeColor,
    required this.type,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.query_stats, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Здесь появится ваш прогресс\nпосле первой тренировки',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (data.length == 1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: themeColor.withOpacity(0.1),
                 shape: BoxShape.circle,
               ),
               child: Icon(Icons.bolt, size: 40, color: themeColor),
             ),
             const SizedBox(height: 16),
             Text(
               'ОТЛИЧНО! ПЕРВЫЙ ШАГ СДЕЛАН.',
               style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1),
             ),
             const SizedBox(height: 4),
             Text(
               'Сделайте еще одну тренировку,\nчтобы увидеть график роста',
               textAlign: TextAlign.center,
               style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
             ),
          ],
        ),
      );
    }

    // Scaling Logic
    final double rawMin = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final double rawMax = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    double buffer = (rawMax - rawMin) * 0.2;
    if (buffer == 0) buffer = rawMax * 0.1 + 5;
    
    final double minY = (rawMin - buffer).clamp(0, double.infinity);
    final double maxY = rawMax + buffer;

    // Nuclear Fix: Calculating Y-axis interval to prevent overlapping and duplicates
    double yInterval = ((maxY - minY) / 5);
    if (yInterval < 1) yInterval = 1;
    // Round to nice numbers if possible (optional but good for UI)
    if (yInterval > 1) yInterval = yInterval.ceilToDouble();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16), // Add padding to prevent cutoff
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      // Nuclear Fix: X-Axis step logic to prevent overlapping dates
                      interval: math.max(1, (data.length / 5)).ceilToDouble(),
                      getTitlesWidget: (v, m) {
                        int i = v.toInt();
                        if (i >= 0 && i < data.length) {
                          return SideTitleWidget(
                            axisSide: m.axisSide,
                            space: 10,
                            child: Text(
                              DateFormat('dd.MM').format(data[i].date),
                              style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
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
                      reservedSize: 45, // Increased space for Y numbers
                      interval: yInterval,
                      getTitlesWidget: (v, m) {
                        // Clean integer display
                        return SideTitleWidget(
                          axisSide: m.axisSide,
                          child: Text(
                            v.toInt().toString(),
                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black,
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final d = data[s.spotIndex];
                        final change = d.percentChange;
                        final color = change >= 0 ? Colors.greenAccent : Colors.redAccent;
                        final changeText = change == 0 ? "Начало" : "${change >= 0 ? '+' : ''}${change.toInt()}%";
                        
                        return LineTooltipItem(
                          '${DateFormat('dd.MM').format(d.date)}\n',
                          GoogleFonts.montserrat(color: Colors.white70, fontSize: 10),
                          children: [
                            TextSpan(
                              text: '${d.value.toInt()} ${_getUnit()}\n',
                              style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1),
                            ),
                            TextSpan(
                              text: '$changeText к прошлому',
                              style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.w900, fontSize: 10),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: themeColor,
                    barWidth: 5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                        radius: 5, color: Colors.black, strokeColor: themeColor, strokeWidth: 3,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [themeColor.withOpacity(0.4), themeColor.withOpacity(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ОСНОВНОЙ ПОКАЗАТЕЛЬ: ${_getMetricName().toUpperCase()} (${_getUnit().toUpperCase()})',
          style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
        ),
      ],
    );
  }

  String _getUnit() {
    final lowerName = exerciseName.toLowerCase();
    if (lowerName.contains('планка')) return 'МИН';
    
    final isBodyweight = lowerName.contains('пресс') || 
                        lowerName.contains('книжка') ||
                        lowerName.contains('гиперэкстензия') ||
                        lowerName.contains('подтягивания') ||
                        lowerName.contains('отжимания от скамьи') ||
                        lowerName.contains('отжимания на брусьях');
    
    if (isBodyweight) return 'ПОВТ';

    switch (type) {
      case ExerciseType.strength: return 'КГ';
      case ExerciseType.bodyweight: return 'ПОВТ';
      case ExerciseType.cardio: return 'КМ';
      case ExerciseType.static: return 'МИН';
    }
  }

  String _getMetricName() {
    if (exerciseName.toLowerCase().contains('планка')) return 'Макс. время';
    switch (type) {
      case ExerciseType.strength: return 'Макс. вес';
      case ExerciseType.bodyweight: return 'Макс. повторы';
      case ExerciseType.cardio: return 'Дистанция';
      case ExerciseType.static: return 'Время';
    }
  }
}
