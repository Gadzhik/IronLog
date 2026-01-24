import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/isar_service.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:intl/intl.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

// Fix: Progress Screen should show ALL exercises
final allExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final service = ref.read(isarServiceProvider);
  return await service.getAllExercises();
});

final searchExerciseProvider = FutureProvider.family<List<Exercise>, String>((ref, query) async {
  final service = ref.read(isarServiceProvider);
  if (query.isEmpty) return service.getAllExercises();
  return service.searchExercises(query);
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
             return '${lastSet.weight}КГ x ${lastSet.reps}';
          }
       }
    }
    return null;
});

class ActiveSessionNotifier extends StateNotifier<WorkoutSession?> {
  final IsarService _service;

  ActiveSessionNotifier(this._service) : super(null);

  void startSession() {
    final now = DateTime.now();
    String defaultName = 'ТРЕНИРОВКА ${DateFormat('dd.MM').format(now)}';
    state = WorkoutSession()..startTime = now..name = defaultName;
    _save();
  }
  
  void updateName(String name) {
     if (state == null) return;
     state!.name = name;
     state = _clone(state!);
     _save();
  }

  void addExercise(Exercise exercise) {
    if (state == null) return;
    
    final entry = WorkoutEntry()
      ..exerciseId = exercise.id
      ..exerciseName = exercise.name
      ..exerciseCategory = exercise.category
      ..exerciseType = exercise.type
      ..sets = [WorkoutSet()..timestamp = DateTime.now()]; 

    final newEntries = List<WorkoutEntry>.from(state!.entries);
    newEntries.add(entry);
    
    state!.entries = newEntries;
    state = _clone(state!);
    _save();
  }

  void addSet(int entryIndex) {
    if (state == null) return;
    if (entryIndex >= state!.entries.length) return;
    
    final entry = state!.entries[entryIndex];
    final newSet = WorkoutSet()..timestamp = DateTime.now();

    final newSets = List<WorkoutSet>.from(entry.sets);
    newSets.add(newSet);
    entry.sets = newSets;

    state = _clone(state!);
    _save();
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
    _save();
  }
  
  void removeSet(int entryIndex, int setIndex) {
     if (state == null) return;
     final entry = state!.entries[entryIndex];
     final newSets = List<WorkoutSet>.from(entry.sets);
     newSets.removeAt(setIndex);
     entry.sets = newSets;
     
     state = _clone(state!);
     _save();
  }
  
  void removeExercise(int entryIndex) {
     if (state == null) return;
     final newEntries = List<WorkoutEntry>.from(state!.entries);
     newEntries.removeAt(entryIndex);
     state!.entries = newEntries;
     state = _clone(state!);
     _save();
  }

  Future<void> finishSession() async {
    if (state == null) return;
    state!.endTime = DateTime.now();
    await _save();
    state = null;
  }
  
  Future<void> _save() async {
    if (state != null) {
      await _service.saveWorkoutSession(state!);
    }
  }

  WorkoutSession _clone(WorkoutSession s) {
    return WorkoutSession()
      ..id = s.id
      ..startTime = s.startTime
      ..endTime = s.endTime
      ..name = s.name
      ..note = s.note
      ..entries = List<WorkoutEntry>.from(s.entries);
  }
}

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, WorkoutSession?>((ref) {
  final service = ref.read(isarServiceProvider);
  return ActiveSessionNotifier(service);
});
