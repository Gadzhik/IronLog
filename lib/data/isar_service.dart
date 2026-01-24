import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/exercise.dart';
import 'models/workout_session.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    try {
      if (Isar.instanceNames.isEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open(
          [ExerciseSchema, WorkoutSessionSchema],
          directory: dir.path,
          inspector: true,
        );
        
        await _seedExercises(isar);
        return isar;
      }
      return Isar.getInstance()!;
    } catch (e) {
      // Emergency: If opening fails (schema mismatch), we might need to delete and retry
      // But for now, just rethrow so UI can handle it.
      print("Isar Initialization Error: $e");
      rethrow;
    }
  }

  Future<void> _seedExercises(Isar isar) async {
    final count = await isar.exercises.count();
    if (count == 0) {
      final exercises = <Exercise>[];
      
      void add(String category, List<String> names) {
        exercises.addAll(names.map((n) => Exercise()..name = n..category = category..type = ExerciseType.strength));
      }
      
      void addCardio(String category, List<String> names) {
        exercises.addAll(names.map((n) => Exercise()..name = n..category = category..type = ExerciseType.cardio));
      }

      add('Грудь', ['Жим штанги лежа', 'Жим гантелей', 'Разводка гантелей', 'Отжимания на брусьях', 'Пек-дек']);
      add('Спина', ['Подтягивания', 'Тяга штанги в наклоне', 'Тяга верхнего блока', 'Тяга гантели одной рукой', 'Гиперэкстензия', 'Становая тяга']);
      add('Ноги', ['Приседания со штангой', 'Жим ногами', 'Разгибания ног в тренажере', 'Сгибания ног', 'Выпады', 'Подъемы на носки']);
      add('Плечи', ['Армейский жим', 'Махи гантелями в стороны', 'Жим гантелей сидя', 'Тяга штанги к подбородку']);
      add('Руки', ['Подъем штанги на бицепс', 'Молотки', 'Французский жим', 'Отжимания от скамьи', 'Разгибания на трицепс в блоке']);
      add('Пресс', ['Скручивания', 'Подъем ног в висе', 'Планка', '"Книжка"']);
      
      // Feature: Cardio
      addCardio('Кардио', ['Беговая дорожка', 'Велотренажер', 'Эллипс', 'Гребля', 'Аэробайк', 'Степпер']);

      await isar.writeTxn(() async {
        await isar.exercises.putAll(exercises);
      });
    } else {
       // Migration/Ensuring
       final cardios = ['Беговая дорожка', 'Велотренажер', 'Эллипс', 'Гребля', 'Аэробайк', 'Степпер'];
       for (var name in cardios) {
          final exists = await isar.exercises.filter().nameEqualTo(name).count() > 0;
          if (!exists) {
             final exercise = Exercise()..name = name..category = 'Кардио'..type = ExerciseType.cardio;
             await isar.writeTxn(() async {
               await isar.exercises.put(exercise);
             });
          }
       }
    }
  }

  // CRUD Helpers
  Future<List<Exercise>> getAllExercises() async {
    final isar = await db;
    return await isar.exercises.where().sortByName().build().findAll();
  }
  
  Future<List<Exercise>> searchExercises(String queryStr) async {
    final isar = await db;
    return await isar.exercises
        .filter()
        .nameContains(queryStr, caseSensitive: false)
        .or()
        .categoryContains(queryStr, caseSensitive: false)
        .sortByName()
        .build()
        .findAll();
  }

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.workoutSessions.put(session);
    });
  }

  Stream<List<WorkoutSession>> watchWorkoutHistory() async* {
    final isar = await db;
    yield* isar.workoutSessions.where().sortByStartTimeDesc().watch(fireImmediately: true);
  }

  Future<List<WorkoutSession>> getWorkoutHistory() async {
    final isar = await db;
    return await isar.workoutSessions.where().sortByStartTimeDesc().build().findAll();
  }
  
  Future<void> deleteWorkout(int id) async {
     final isar = await db;
     await isar.writeTxn(() async {
       await isar.workoutSessions.delete(id);
     });
  }
  
  Future<void> clearAllData() async {
      final isar = await db;
      await isar.writeTxn(() async {
        await isar.workoutSessions.clear();
      });
  }
  
  // Stats: Integrated logic for Strength (Weight) and Cardio (Duration/Distance)
  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId, ExerciseType type) async {
    final isar = await db;
    // Fix: Ensure we fetch ALL sessions for full history
    final sessions = await isar.workoutSessions.where().sortByStartTime().build().findAll();
    
    final List<Map<String, dynamic>> history = [];
    
    for (var session in sessions) {
      for (var entry in session.entries) {
        if (entry.exerciseId == exerciseId) {
          bool hasCompletedSet = entry.sets.any((s) => s.isCompleted);
          if (!hasCompletedSet) continue;

          if (type == ExerciseType.strength) {
            double maxW = 0;
            for (var set in entry.sets) {
              if (set.isCompleted && set.weight > maxW) maxW = set.weight;
            }
            history.add({'date': session.startTime, 'value': maxW});
          } else {
            // Cardio: Track Total Duration per session in MINUTES
            int totalDurationSecs = 0;
            for (var set in entry.sets) {
              if (set.isCompleted) {
                totalDurationSecs += set.duration;
              }
            }
            if (totalDurationSecs > 0) {
              history.add({
                'date': session.startTime, 
                'value': totalDurationSecs.toDouble() / 60.0, // Convert to minutes for Y-axis
              });
            }
          }
        }
      }
    }
    return history;
  }
}
