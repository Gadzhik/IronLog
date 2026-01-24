import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/isar_service.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:intl/intl.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final service = ref.read(isarServiceProvider);
  return await service.getAllExercises();
});

final allExercisesProvider = exercisesProvider;

final searchExerciseProvider = FutureProvider.family<List<Exercise>, String>((ref, query) async {
  final service = ref.read(isarServiceProvider);
  if (query.isEmpty) return service.getAllExercises();
  return service.searchExercises(query);
});

// Bug Fix: Use StreamProvider for reactive updates
final historyProvider = StreamProvider<List<WorkoutSession>>((ref) {
  final service = ref.read(isarServiceProvider);
  return service.watchWorkoutHistory();
});

// Feature: Smart hint
final lastPerformanceProvider = FutureProvider.family<String?, int>((ref, exerciseId) async {
   final service = ref.read(isarServiceProvider);
   return service.getLastPerformance(exerciseId);
});

class ActiveSessionNotifier extends StateNotifier<WorkoutSession?> {
  final IsarService _service;

  ActiveSessionNotifier(this._service) : super(null);

  void startSession() {
    final now = DateTime.now();
    // Feature: Default Naming
    String defaultName = 'Тренировка от ${DateFormat('dd.MM').format(now)}';
    
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

    // We must clone the entries list to ensure Riverpod detects change
    // Make sure we are creating a deep copy of entries list structure
    final newEntries = List<WorkoutEntry>.from(state!.entries);
    newEntries.add(entry);
    
    state!.entries = newEntries;
    state = _clone(state!);
    _save();
  }

  void addSet(int entryIndex) {
    if (state == null) return;
    if (entryIndex >= state!.entries.length) return;
    
    final entries = state!.entries;
    final entry = entries[entryIndex];
    
    // Logic Change: New set inputs must be empty/zero
    double prevWeight = 0;
    int prevReps = 0;
    double prevDist = 0;
    int prevDur = 0;

    final newSet = WorkoutSet()
       ..weight = prevWeight
       ..reps = prevReps
       ..distance = prevDist
       ..duration = prevDur
       ..timestamp = DateTime.now();

    final newSets = List<WorkoutSet>.from(entry.sets);
    newSets.add(newSet);
    entry.sets = newSets;

    state = _clone(state!);
    _save();
  }

  // Feature: Support cardio fields
  void updateSet(int entryIndex, int setIndex, {double? weight, int? reps, double? distance, int? duration, bool? isCompleted}) {
    if (state == null) return;
    final set = state!.entries[entryIndex].sets[setIndex];
    
    if (weight != null) set.weight = weight;
    if (reps != null) set.reps = reps;
    if (distance != null) set.distance = distance;
    if (duration != null) set.duration = duration;
    if (isCompleted != null) set.isCompleted = isCompleted;
    
    // Explicitly re-assign to trigger dirty check if needed (Isar embedded objects are mutable but state notifier needs ref change)
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
  
  // Feature: Removal of exercise
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
      ..entries = s.entries; // Shallow copy of list is fine if we replaced the list itself top-level
  }
}

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, WorkoutSession?>((ref) {
  final service = ref.read(isarServiceProvider);
  return ActiveSessionNotifier(service);
});

final exercisesForRangeProvider = FutureProvider.family<List<Exercise>, Duration?>((ref, duration) async {
  final service = ref.read(isarServiceProvider);
  if (duration == null) return service.getAllExercises();
  final start = DateTime.now().subtract(duration);
  // Ensure we use the Start of that Day for the query
  final startOfDay = DateTime(start.year, start.month, start.day);
  return service.getExercisesForRange(startOfDay);
});
