import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/progress_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressChartWidget extends StatelessWidget {
  final List<ProgressDataPoint> data;
  final Color themeColor;
  final ProgressMetric metric;

  const ProgressChartWidget({
    super.key,
    required this.data,
    required this.themeColor,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Здесь появится ваш прогресс\nпосле первой тренировки',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final bool isDual = metric == ProgressMetric.cardioVolume;

    // Scaling with 10% buffer
    final double rawMin = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final double rawMax = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    double buffer = (rawMax - rawMin) * 0.15;
    if (buffer == 0) buffer = rawMax * 0.1 + 5;

    final double minY = (rawMin - buffer).clamp(0, double.infinity);
    final double maxY = rawMax + buffer;

    // Fixed Step/Interval for clean Y-axis
    double interval = ((maxY - minY) / 5);
    if (interval <= 0) interval = 1;

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 16, bottom: 8),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, m) {
                  int i = v.toInt();
                  if (i >= 0 && i < data.length && (data.length < 6 || i % (math.max(1, data.length ~/ 3)) == 0)) {
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
                reservedSize: 42,
                interval: interval,
                getTitlesWidget: (v, m) {
                  if (v == minY || v > maxY) return const SizedBox.shrink();
                  return Text(
                    v.toInt().toString(),
                    style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.black.withOpacity(0.95),
              getTooltipItems: (spots) {
                return spots.map((s) {
                  final d = data[s.spotIndex];
                  final change = d.percentChange;
                  final color = change >= 0 ? Colors.greenAccent : Colors.redAccent;
                  
                  return LineTooltipItem(
                    '', 
                    const TextStyle(),
                    children: [
                      TextSpan(
                        text: 'Дата: ${DateFormat('dd.MM').format(d.date)}\n',
                        style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 10),
                      ),
                      TextSpan(
                        text: 'Результат: ${s.y % 1 == 0 ? s.y.toInt() : s.y.toStringAsFixed(1)}\n',
                        style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextSpan(
                        text: 'Рост: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // SMA Trend Line (Ghost Line)
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.trendValue)).toList(),
              isCurved: true,
              color: themeColor.withOpacity(0.1),
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            // Main Progress Line
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              color: themeColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, p, bar, i) {
                  final growth = data[i].isGrowth;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: growth ? Colors.greenAccent : Colors.black,
                    strokeColor: growth ? Colors.greenAccent : themeColor,
                    strokeWidth: 2,
                  );
                },
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
    );
  }
}
