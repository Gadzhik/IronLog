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

  const ProgressChartWidget({
    super.key,
    required this.data,
    required this.themeColor,
    required this.type,
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

    // Scaling Logic for Primary Axis
    final double rawMin = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final double rawMax = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    double buffer = (rawMax - rawMin) * 0.2;
    if (buffer == 0) buffer = rawMax * 0.1 + 5;
    final double minY = (rawMin - buffer).clamp(0, double.infinity);
    final double maxY = rawMax + buffer;

    // Scaling Logic for Secondary Axis (if applicable)
    bool hasSecondary = data.any((e) => e.secondaryValue != null && e.secondaryValue! > 0);
    double secondaryMinY = 0;
    double secondaryMaxY = 1;
    if (hasSecondary) {
      final double secRawMin = data.map((e) => e.secondaryValue ?? 0).reduce((a, b) => a < b ? a : b);
      final double secRawMax = data.map((e) => e.secondaryValue ?? 0).reduce((a, b) => a > b ? a : b);
      double secBuffer = (secRawMax - secRawMin) * 0.2;
      if (secBuffer == 0) secBuffer = secRawMax * 0.1 + 5;
      secondaryMinY = (secRawMin - secBuffer).clamp(0, double.infinity);
      secondaryMaxY = secRawMax + secBuffer;
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, m) {
                      int i = v.toInt();
                      if (i >= 0 && i < data.length && (data.length < 5 || i % (math.max(1, data.length ~/ 2)) == 0)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
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
                    reservedSize: 40,
                    getTitlesWidget: (v, m) {
                      if (v == minY || v > maxY) return const SizedBox.shrink();
                      return Text(
                        v.toInt().toString(),
                        style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: hasSecondary,
                    reservedSize: 40,
                    getTitlesWidget: (v, m) {
                      if (!hasSecondary) return const SizedBox.shrink();
                      // Map primary Y value to secondary range for display
                      double relative = (v - minY) / (maxY - minY);
                      double actualSec = secondaryMinY + (relative * (secondaryMaxY - secondaryMinY));
                      return Text(
                        actualSec.toInt().toString(),
                        style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.withOpacity(0.5)),
                      );
                    },
                  ),
                ),
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
                          if (d.secondaryValue != null && d.secondaryValue! > 0)
                            TextSpan(
                              text: '${d.secondaryValue!.toInt()} ${_getSecondaryUnit()}\n',
                              style: GoogleFonts.bebasNeue(color: themeColor.withOpacity(0.7), fontSize: 18, letterSpacing: 1),
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
                if (hasSecondary)
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      double val = e.value.secondaryValue ?? 0;
                      // Normalize to primary range
                      double normalized = minY + ((val - secondaryMinY) / (secondaryMaxY - secondaryMinY) * (maxY - minY));
                      return FlSpot(e.key.toDouble(), normalized);
                    }).toList(),
                    isCurved: true,
                    color: themeColor.withOpacity(0.3),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ОСНОВНОЙ ПОКАЗАТЕЛЬ: ${_getMetricName().toUpperCase()} (${_getUnit().toUpperCase()})',
          style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
        ),
        if (hasSecondary)
          Text(
            'ДОПОЛНИТЕЛЬНО: ${_getSecondaryMetricName().toUpperCase()} (${_getSecondaryUnit().toUpperCase()})',
            style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey.withOpacity(0.6), letterSpacing: 1),
          ),
      ],
    );
  }

  String _getUnit() {
    switch (type) {
      case ExerciseType.strength: return 'КГ';
      case ExerciseType.bodyweight: return 'ПОВТ';
      case ExerciseType.cardio: return 'КМ';
      case ExerciseType.static: return 'МИН';
    }
  }

  String _getSecondaryUnit() {
    switch (type) {
      case ExerciseType.bodyweight: return 'КГ';
      case ExerciseType.cardio: return 'МИН';
      default: return '';
    }
  }

  String _getMetricName() {
    switch (type) {
      case ExerciseType.strength: return 'Макс. вес';
      case ExerciseType.bodyweight: return 'Макс. повторы';
      case ExerciseType.cardio: return 'Дистанция';
      case ExerciseType.static: return 'Время';
    }
  }

  String _getSecondaryMetricName() {
    switch (type) {
      case ExerciseType.bodyweight: return 'С весом';
      case ExerciseType.cardio: return 'Время';
      default: return '';
    }
  }
}
