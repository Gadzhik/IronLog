import 'package:isar_community/isar.dart';
import 'exercise.dart';

part 'workout_session.g.dart';

@collection
class WorkoutSession {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime startTime;

  DateTime? endTime;
  
  String? name; // Feature: Workout naming

  String? note;

  List<WorkoutEntry> entries = [];
  
  double get totalVolume {
    double total = 0;
    for (var entry in entries) {
      for (var set in entry.sets) {
        if (set.isCompleted) {
          total += set.weight * set.reps;
        }
      }
    }
    return total;
  }
}

@embedded
class WorkoutEntry {
  int? exerciseId; 
  String? exerciseName; 
  String? exerciseCategory;
  
  @Enumerated(EnumType.ordinal)
  ExerciseType exerciseType = ExerciseType.strength;

  List<WorkoutSet> sets = [];
}

@embedded
class WorkoutSet {
  double weight = 0; // kg
  int reps = 0;
  
  double distance = 0; // km, for cardio
  int duration = 0; // seconds, for cardio
  
  bool isCompleted = false;
  late DateTime timestamp;
}
