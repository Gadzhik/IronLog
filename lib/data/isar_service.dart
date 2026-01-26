import 'package:flutter/foundation.dart';
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
      debugPrint("Isar Initialization Error: $e");
      rethrow;
    }
  }

  Future<void> _seedExercises(Isar isar) async {
    final count = await isar.exercises.count();
    if (count == 0) {
      final exercises = <Exercise>[];
      
      void add(String category, List<String> names, [ExerciseType type = ExerciseType.strength]) {
        for (var name in names) {
          ExerciseType finalType = type;
          
          // RE-SEEDING RULES: Assign specific types based on names
          if (name == 'Планка') {
            finalType = ExerciseType.static;
          } else if (category == 'Пресс' || 
                    name == 'Гиперэкстензия' || 
                    name == 'Подтягивания' || 
                    name == 'Отжимания от скамьи' || 
                    name == 'Отжимания на брусьях') {
            finalType = ExerciseType.bodyweight;
          }
          
          exercises.add(Exercise()
            ..name = name
            ..category = category
            ..type = finalType);
        }
      }

      // Strength (Weight + Reps)
      add('Грудь', ['Жим штанги лежа', 'Жим гантелей', 'Разводка гантелей', 'Пек-дек'], ExerciseType.strength);
      add('Спина', ['Тяга штанги в наклоне', 'Тяга верхнего блока', 'Тяга гантели одной рукой', 'Становая тяга'], ExerciseType.strength);
      add('Ноги', ['Приседания со штангой', 'Жим ногами', 'Разгибания ног в тренажере', 'Сгибания ног', 'Выпады', 'Подъемы на носки'], ExerciseType.strength);
      add('Плечи', ['Армейский жим', 'Махи гантелями в стороны', 'Жим гантелей сидя', 'Тяга штанги к подбородку'], ExerciseType.strength);
      add('Руки', ['Подъем штанги на бицепс', 'Молотки', 'Французский жим', 'Разгибания на трицепс в блоке'], ExerciseType.strength);
      
      // Bodyweight & Category Specific
      add('Грудь', ['Отжимания на брусьях', 'Отжимания от пола']);
      add('Спина', ['Подтягивания', 'Гиперэкстензия']);
      add('Руки', ['Отжимания от скамьи']);
      add('Ноги', ['Приседания без веса'], ExerciseType.bodyweight);
      add('Пресс', ['Скручивания', 'Подъем ног в висе', 'Книжка', 'Планка']);
      
      // Cardio (KM + Minutes)
      add('Кардио', ['Беговая дорожка', 'Велотренажер', 'Эллипс', 'Гребля', 'Аэробайк', 'Степпер'], ExerciseType.cardio);

      await isar.writeTxn(() async {
        await isar.exercises.putAll(exercises);
      });
    }
  }

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
    if (!isar.isOpen) {
      throw Exception('База данных закрыта или не инициализирована');
    }
    
    // 5-second timeout protection to prevent infinite loading
    try {
      await isar.writeTxn(() async {
        await isar.workoutSessions.put(session);
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Превышено время ожидания записи в базу'),
      );
    } catch (e) {
      debugPrint('Isar Save Error: $e');
      rethrow;
    }
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
}
