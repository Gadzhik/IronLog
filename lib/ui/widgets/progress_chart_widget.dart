import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/progress_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressChartWidget extends StatelessWidget {
  final List<ProgressDataPoint> data;
  final Color themeColor;
  final bool isCardio;

  const ProgressChartWidget({
    super.key,
    required this.data,
    required this.themeColor,
    required this.isCardio,
  });

  @override
  Widget build(BuildContext context) {
    // Scenario 1: No data
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

    // Scenario 2: Only one data point
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

    return LineChart(
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                final arrow = change >= 0 ? '👍' : '💪';
                final changeText = change == 0 ? "Начало пути" : "${change >= 0 ? '+' : ''}${change.toInt()}% к прошлой цели";
                
                return LineTooltipItem(
                  '${DateFormat('dd.MM').format(d.date)}\n',
                  GoogleFonts.montserrat(color: Colors.white70, fontSize: 10),
                  children: [
                    TextSpan(
                      text: '${s.y.toInt()} ${isCardio ? 'КМ' : 'КГ'}\n',
                      style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1),
                    ),
                    TextSpan(
                      text: '$changeText $arrow',
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
                radius: 5,
                color: Colors.black,
                strokeColor: themeColor,
                strokeWidth: 3,
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
    );
  }
}
