import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/isar_service.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final allExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final service = ref.read(isarServiceProvider);
  return await service.getAllExercises();
});

final searchExerciseProvider = FutureProvider.family<List<Exercise>, String>((ref, query) async {
  final service = ref.read(isarServiceProvider);
  if (query.isEmpty) return await service.getAllExercises();
  return await service.searchExercises(query);
});

final historyProvider = StreamProvider<List<WorkoutSession>>((ref) {
  final service = ref.read(isarServiceProvider);
  return service.watchWorkoutHistory();
});

final lastPerformanceProvider = FutureProvider.family<String?, int>((ref, exerciseId) async {
   final service = ref.read(isarServiceProvider);
   final sessions = await service.getWorkoutHistory();
       
    for(var s in sessions) {
       for(var e in s.entries) {
          if (e.exerciseId == exerciseId && e.sets.any((s) => s.isCompleted)) {
             final completedSets = e.sets.where((s) => s.isCompleted).toList();
             if (completedSets.isEmpty) continue;
             
             final lastSet = completedSets.last;
             if (e.exerciseType == ExerciseType.cardio) {
               return '${lastSet.distance}КМ / ${lastSet.duration}МИН';
             }
             
             // Rule for specific exercises (bodyweight/abs)
             final name = e.exerciseName ?? '';
             final category = e.exerciseCategory ?? '';
             
             final isBodyweight = category.contains('Пресс') || 
                                  name.contains('Книжка') ||
                                  name.contains('Гиперэкстензия') ||
                                  name.contains('Подтягивания') ||
                                  name.contains('Отжимания на брусьях') ||
                                  name.contains('Отжимания от скамьи');

             if (isBodyweight) {
                return '${lastSet.reps} ПОВТ';
             }
             
             return '${lastSet.weight}КГ x ${lastSet.reps}';
          }
       }
    }
    return null;
});

class ActiveSessionNotifier extends StateNotifier<WorkoutSession?> {
  final IsarService _service;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ActiveSessionNotifier(this._service) : super(null);

  void startSession() {
    final now = DateTime.now();
    String defaultName = 'ТРЕНИРОВКА ${DateFormat('dd.MM').format(now)}';
    state = WorkoutSession()..startTime = now..name = defaultName;
  }
  
  void updateName(String name) {
     if (state == null) return;
     state!.name = name;
     state = _clone(state!);
  }

  void addExercise(Exercise exercise) {
    if (state == null) return;
    final entry = WorkoutEntry()
      ..exerciseId = exercise.id
      ..exerciseName = exercise.name
      ..exerciseCategory = exercise.category
      ..exerciseType = exercise.type
      ..sets = [WorkoutSet()..timestamp = DateTime.now()]; 
    state!.entries.add(entry);
    state = _clone(state!);
  }

  void addSet(int entryIndex) {
    if (state == null) return;
    state!.entries[entryIndex].sets.add(WorkoutSet()..timestamp = DateTime.now());
    state = _clone(state!);
  }

  void updateSet(int entryIndex, int setIndex, {double? weight, int? reps, double? distance, int? duration, bool? isCompleted}) {
    if (state == null) return;
    final set = state!.entries[entryIndex].sets[setIndex];
    if (weight != null) set.weight = weight;
    if (reps != null) set.reps = reps;
    if (distance != null) set.distance = distance;
    if (duration != null) set.duration = duration;
    if (isCompleted != null) set.isCompleted = isCompleted;
    state = _clone(state!);
  }
  
  void removeSet(int entryIndex, int setIndex) {
     if (state == null) return;
     state!.entries[entryIndex].sets.removeAt(setIndex);
     state = _clone(state!);
  }
  
  void removeExercise(int entryIndex) {
     if (state == null) return;
     state!.entries.removeAt(entryIndex);
     state = _clone(state!);
  }

  // FAIL-SAFE FINISH LOGIC
  // Removed WidgetRef dependency for cleaner architecture
  Future<void> finishSession() async {
    if (state == null || _isLoading) return;
    
    _isLoading = true;
    try {
      state!.endTime = DateTime.now();
      
      // Perform the write transaction using injected service
      await _service.saveWorkoutSession(state!);
      state = null;
    } catch (e) {
      debugPrint('FAIL-SAFE: Save failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  WorkoutSession _clone(WorkoutSession s) {
    return WorkoutSession()
      ..id = s.id
      ..startTime = s.startTime
      ..endTime = s.endTime
      ..name = s.name
      ..note = s.note
      ..entries = s.entries.map((e) => WorkoutEntry()
        ..exerciseId = e.exerciseId
        ..exerciseName = e.exerciseName
        ..exerciseCategory = e.exerciseCategory
        ..exerciseType = e.exerciseType
        ..sets = e.sets.map((set) => WorkoutSet()
          ..weight = set.weight
          ..reps = set.reps
          ..distance = set.distance
          ..duration = set.duration
          ..isCompleted = set.isCompleted
          ..timestamp = set.timestamp).toList()
      ).toList();
  }
}

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, WorkoutSession?>((ref) {
  final service = ref.read(isarServiceProvider);
  return ActiveSessionNotifier(service);
});
