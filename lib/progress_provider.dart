import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'dart:math';

enum ProgressMetric { strength1RM, strengthVolume, cardioPace, cardioVolume }

class ProgressDataPoint {
  final DateTime date;
  final double value;
  final double trendValue;
  final double? secondaryValue;
  final double percentChange;
  final bool isGrowth;

  const ProgressDataPoint({
    required this.date,
    required this.value,
    required this.trendValue,
    this.secondaryValue,
    this.percentChange = 0,
    this.isGrowth = false,
  });
}

final progressMetricProvider = StateProvider<ProgressMetric>((ref) => ProgressMetric.strength1RM);

final progressHistoryProvider = FutureProvider.family<List<ProgressDataPoint>, int>((ref, exerciseId) async {
  final isar = ref.read(isarServiceProvider);
  final rawHistory = await isar.getExerciseHistory(exerciseId);
  final metric = ref.watch(progressMetricProvider);

  if (rawHistory.isEmpty) return [];

  // Group by Date (only YYYY-MM-DD) to find the best result per day
  Map<String, Map<String, dynamic>> dailyBest = {};

  for (var session in rawHistory) {
    final date = session['date'] as DateTime;
    final dateKey = "${date.year}-${date.month}-${date.day}";
    final sets = session['sets'] as List<dynamic>;
    final typeIndex = session['type'] as int;
    final type = ExerciseType.values[typeIndex];

    double dailyVal = 0;
    double? dailySec;

    if (type == ExerciseType.strength) {
      if (metric == ProgressMetric.strength1RM) {
        for (var s in sets) {
          double w = (s['weight'] as num).toDouble();
          int r = (s['reps'] as num).toInt();
          if (r > 0 && w > 0) {
            double current1RM = r == 1 ? w : w * (36 / (37 - min(r, 10)));
            if (current1RM > dailyVal) dailyVal = current1RM;
          }
        }
      } else if (metric == ProgressMetric.strengthVolume) {
        double currentVol = 0;
        for (var s in sets) {
          currentVol += (s['weight'] as num) * (s['reps'] as num);
        }
        dailyVal = currentVol;
      }
    } else {
      // Cardio
      double totalDist = 0;
      double totalDurMin = 0;
      for (var s in sets) {
        totalDist += (s['distance'] as num).toDouble();
        totalDurMin += (s['duration'] as num).toDouble();
      }

      if (metric == ProgressMetric.cardioPace) {
        // Pace (min/km) - Lower is better usually, but the user wants "lifting more/running longer"
        // Let's stick to pace for now or flip it if requested. Usually pace is min/km.
        if (totalDist > 0) dailyVal = totalDurMin / totalDist;
        dailySec = totalDist;
      } else if (metric == ProgressMetric.cardioVolume) {
        dailyVal = totalDist;
        dailySec = totalDurMin;
      }
    }

    if (dailyVal > 0) {
       if (!dailyBest.containsKey(dateKey) || dailyVal > dailyBest[dateKey]!['value']) {
         dailyBest[dateKey] = {
           'date': date,
           'value': dailyVal,
           'secondary': dailySec,
         };
       }
    }
  }

  List<ProgressDataPoint> points = dailyBest.values.map((v) => ProgressDataPoint(
    date: v['date'] as DateTime,
    value: v['value'] as double,
    secondaryValue: v['secondary'] as double?,
    trendValue: 0,
  )).toList();

  points.sort((a, b) => a.date.compareTo(b.date));

  // Finalize with Trend and Change
  List<ProgressDataPoint> finalized = [];
  const int window = 3;

  for (int i = 0; i < points.length; i++) {
    double sum = 0;
    int count = 0;
    for (int j = max(0, i - window + 1); j <= i; j++) {
      sum += points[j].value;
      count++;
    }
    double trend = sum / count;

    double pct = 0;
    bool growth = false;
    if (i > 0) {
      pct = ((points[i].value - finalized[i-1].value) / finalized[i-1].value) * 100;
      growth = points[i].value > finalized[i-1].value;
    }

    finalized.add(ProgressDataPoint(
      date: points[i].date,
      value: points[i].value,
      trendValue: trend,
      secondaryValue: points[i].secondaryValue,
      percentChange: pct,
      isGrowth: growth,
    ));
  }

  return finalized;
});
