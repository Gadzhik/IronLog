import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:isar_community/isar.dart';

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

final progressStreamProvider = StreamProvider.family<List<ProgressDataPoint>, int>((ref, exerciseId) async* {
  final isarService = ref.read(isarServiceProvider);
  final db = await isarService.db;
  
  // REACTIVE STREAM using .watch()
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

          // SPECIAL LOGIC: Identify exercise type by name/category or official type
          final String name = entry.exerciseName ?? '';
          final String category = entry.exerciseCategory ?? '';
          
          final isBodyweight = category == 'Пресс' || 
                              ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(name);
          final isPlank = name == 'Планка';
          final isStatic = entry.exerciseType == ExerciseType.static || isPlank;
          
          if (isPlank) {
            // "Планка" handles duration in minutes for the chart
            for (var s in completedSets) {
              double mins = s.duration / 60.0;
              if (mins > value) value = mins;
            }
          } else if (isBodyweight) {
            // Bodyweight handles REPS as primary metric
            for (var s in completedSets) {
              if (s.reps > value) value = s.reps.toDouble();
              // Extra weight as secondary
              if (s.weight > (secondary ?? 0)) secondary = s.weight;
            }
          } else if (entry.exerciseType == ExerciseType.cardio) {
            // Cardio: Distance as primary
            double totalDist = 0;
            double totalDur = 0;
            for (var s in completedSets) {
              totalDist += s.distance;
              totalDur += s.duration.toDouble();
            }
            value = totalDist;
            secondary = totalDur;
          } else {
            // Strength (Default): Weight as primary
            for (var s in completedSets) {
              if (s.weight > value) value = s.weight;
            }
          }

          if (value > 0 || (secondary != null && secondary > 0)) {
            points.add(ProgressDataPoint(
              date: session.startTime,
              value: value,
              secondaryValue: secondary,
            ));
          }
          break; // Found the exercise in this session, move to next session
        }
      }
    }

    // Process percent changes and growth
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
