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
    return Future.value(Isar.getInstance());
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
      addCardio('Кардио', ['Беговая дорожка', 'Велотренажер', 'Эллипс', 'Гребля', 'Аэробайк']);

      await isar.writeTxn(() async {
        await isar.exercises.putAll(exercises);
      });
    } else {
       // Migration logic if needed to add types to existing exercises?
       // For now, assuming fresh install or okay with defaults. 
       // If running on existing DB, existing exercises might have null type or default index. 
       // Since the field has a default value, Isar handles it on next read/write.
       
       // Let's ensure Cardio exists if update
       final hasCardio = await isar.exercises.filter().categoryEqualTo('Кардио').isNotEmpty();
       if (!hasCardio) {
          final cardios = ['Беговая дорожка', 'Велотренажер', 'Эллипс', 'Гребля'].map(
            (n) => Exercise()..name = n..category = 'Кардио'..type = ExerciseType.cardio
          ).toList();
          await isar.writeTxn(() async {
            await isar.exercises.putAll(cardios);
          });
       }
    }
  }

  // CRUD Helpers
  Future<List<Exercise>> getAllExercises() async {
    final isar = await db;
    return await isar.exercises.where().findAll();
  }
  
  Future<List<Exercise>> searchExercises(String query) async {
    final isar = await db;
    return await isar.exercises
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .categoryContains(query, caseSensitive: false)
        .findAll();
  }

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.workoutSessions.put(session);
    });
  }

  // Bug Fix: Stream for reactive updates
  Stream<List<WorkoutSession>> watchWorkoutHistory() async* {
    final isar = await db;
    yield* isar.workoutSessions.where().sortByStartTimeDesc().watch(fireImmediately: true);
  }

  Future<List<WorkoutSession>> getWorkoutHistory() async {
    final isar = await db;
    return await isar.workoutSessions.where().sortByStartTimeDesc().findAll();
  }
  
  // Feature: Delete
  Future<void> deleteWorkout(int id) async {
     final isar = await db;
     await isar.writeTxn(() async {
       await isar.workoutSessions.delete(id);
     });
  }
  
  // Feature: Clear All
  Future<void> clearAllData() async {
      final isar = await db;
      await isar.writeTxn(() async {
        await isar.workoutSessions.clear();
      });
  }
  
  // Smart: Export
  Future<String> exportData() async {
    final isar = await db;
    final sessions = await isar.workoutSessions.where().findAll();
    // Simple JSON export logic
    // Nested objects need toJson or manual map. 
    // Since we used Isar generator, we might verify if toJson is generated or do it manually.
    // Manual map for safety:
    final data = sessions.map((s) => {
      'startTime': s.startTime.toIso8601String(),
      'endTime': s.endTime?.toIso8601String(),
      'name': s.name,
      'entries': s.entries.map((e) => {
        'exercise': e.exerciseName,
        'category': e.exerciseCategory,
        'sets': e.sets.map((set) => {
           'weight': set.weight,
           'reps': set.reps,
           'distance': set.distance,
           'time': set.duration
        }).toList(),
      }).toList()
    }).toList();
    
    return jsonEncode(data);
  }

  // Smart: Last Session Hint
  Future<String?> getLastPerformance(int exerciseId) async {
    final isar = await db;
    // Find sessions containing this exercise, sorted by date desc
    final sessions = await isar.workoutSessions.filter()
       .entriesElement((q) => q.exerciseIdEqualTo(exerciseId))
       .sortByStartTimeDesc()
       .findAll();
       
    if (sessions.isNotEmpty) {
      // Find the specific entry
      for(var s in sessions) {
         for(var e in s.entries) {
            if (e.exerciseId == exerciseId && e.sets.isNotEmpty) {
               // Return last set or max set? Usually last set of last session is good reference.
               final lastSet = e.sets.last;
               if (e.exerciseType == ExerciseType.cardio) {
                 return '${lastSet.distance}км / ${lastSet.duration}с';
               }
               return '${lastSet.weight}кг x ${lastSet.reps}';
            }
         }
      }
    }
    return null;
  }
  
  // Stats
  Future<List<Map<String, dynamic>>> getMaxWeightHistory(int exerciseId, {DateTime? after}) async {
    final isar = await db;
    var builder = isar.workoutSessions.where().sortByStartTime();
    
    if (after != null) {
      builder = isar.workoutSessions.filter().startTimeGreaterThan(after).sortByStartTime();
    }
    
    final sessions = await builder.findAll();
    
    List<Map<String, dynamic>> history = [];
    
    for (var session in sessions) {
      for (var entry in session.entries) {
        if (entry.exerciseId == exerciseId) {
          if (entry.exerciseType == ExerciseType.cardio) {
             // For cardio maybe track max distance or duration?
             // Let's skip chart for cardio or use duration 
             continue;
          }
          
          double maxW = 0;
          for (var set in entry.sets) {
             if (set.weight > maxW) maxW = set.weight;
          }
          if (maxW > 0) {
            history.add({'date': session.startTime, 'weight': maxW});
          }
        }
      }
    }
    return history;
  }
}
