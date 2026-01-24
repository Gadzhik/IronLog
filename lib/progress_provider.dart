import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:isar_community/isar.dart'; // Ensure Isar import for watch()
import 'dart:math';

enum ProgressMetric { strengthBestSet, cardioTotal }

class ProgressDataPoint {
  final DateTime date;
  final double value;
  final double? secondaryValue;
  final double percentChange;
  final bool isGrowth;

  const ProgressDataPoint({
    required this.date,
    required this.value,
    this.secondaryValue,
    this.percentChange = 0,
    this.isGrowth = false,
  });
}

final progressMetricProvider = StateProvider<ProgressMetric>((ref) => ProgressMetric.strengthBestSet);

// Reactive StreamProvider that watches Isar for any workout session changes
final progressStreamProvider = StreamProvider.family<List<ProgressDataPoint>, int>((ref, exerciseId) async* {
  final isarService = ref.read(isarServiceProvider);
  final metric = ref.watch(progressMetricProvider);
  
  final db = await isarService.db;
  
  // Isar watch logic: build the query first, then watch it
  final query = db.workoutSessions.where().sortByStartTime().build();
  
  yield* query.watch(fireImmediately: true).map((sessions) {
    if (sessions.isEmpty) return [];

    List<ProgressDataPoint> points = [];
    
    for (var session in sessions) {
      for (var entry in session.entries) {
        if (entry.exerciseId == exerciseId) {
          final completedSets = entry.sets.where((s) => s.isCompleted).toList();
          if (completedSets.isEmpty) continue;

          double value = 0;
          double? secondary;

          if (entry.exerciseType == ExerciseType.strength) {
            for (var s in completedSets) {
              if (s.weight > value) value = s.weight;
            }
          } else {
            double totalDist = 0;
            double totalDur = 0;
            for (var s in completedSets) {
              totalDist += s.distance;
              totalDur += s.duration.toDouble();
            }
            value = totalDist;
            secondary = totalDur;
          }

          if (value > 0 || (secondary != null && secondary > 0)) {
            points.add(ProgressDataPoint(
              date: session.startTime,
              value: value,
              secondaryValue: secondary,
            ));
          }
          break; 
        }
      }
    }

    // Sort by date and calculate improvements
    points.sort((a, b) => a.date.compareTo(b.date));

    List<ProgressDataPoint> finalized = [];
    for (int i = 0; i < points.length; i++) {
        double pct = 0;
        bool growth = false;
        if (i > 0) {
          double prev = points[i-1].value;
          if (prev > 0) {
            pct = ((points[i].value - prev) / prev) * 100;
            growth = points[i].value > prev;
          }
        }
        finalized.add(ProgressDataPoint(
          date: points[i].date,
          value: points[i].value,
          secondaryValue: points[i].secondaryValue,
          percentChange: pct,
          isGrowth: growth,
        ));
    }
    return finalized;
  });
});
