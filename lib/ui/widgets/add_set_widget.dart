import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddSetWidget extends ConsumerStatefulWidget {
  final int entryIndex;
  final int setIndex;
  final WorkoutSet set;
  final ExerciseType type;
  final String exerciseName;
  final String exerciseCategory;

  const AddSetWidget({
    super.key,
    required this.entryIndex,
    required this.setIndex,
    required this.set,
    required this.type,
    required this.exerciseName,
    required this.exerciseCategory,
  });

  @override
  ConsumerState<AddSetWidget> createState() => _AddSetWidgetState();
}

class _AddSetWidgetState extends ConsumerState<AddSetWidget> {
  late TextEditingController _col1Controller;
  late TextEditingController _col2Controller;

  @override
  void initState() {
    super.initState();
    _col1Controller = TextEditingController(text: _getInitialValue1());
    _col2Controller = TextEditingController(text: _getInitialValue2());
  }

  @override
  void dispose() {
    _col1Controller.dispose();
    _col2Controller.dispose();
    super.dispose();
  }

  String _getInitialValue1() {
    if (widget.exerciseName == 'Планка') {
      return widget.set.duration == 0 ? '' : (widget.set.duration / 60).toStringAsFixed(1).replaceAll('.0', '');
    }
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
      return widget.set.reps == 0 ? '' : widget.set.reps.toString();
    }
    switch (widget.type) {
      case ExerciseType.strength: return widget.set.weight == 0 ? '' : widget.set.weight.toString().replaceAll('.0', '');
      case ExerciseType.bodyweight: return widget.set.reps == 0 ? '' : widget.set.reps.toString();
      case ExerciseType.cardio: return widget.set.distance == 0 ? '' : widget.set.distance.toString().replaceAll('.0', '');
      case ExerciseType.static: return widget.set.duration == 0 ? '' : (widget.set.duration / 60).toStringAsFixed(1).replaceAll('.0', '');
    }
  }

  String _getInitialValue2() {
    if (widget.exerciseName == 'Планка' || widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
      return '';
    }
    switch (widget.type) {
      case ExerciseType.strength: return widget.set.reps == 0 ? '' : widget.set.reps.toString();
      case ExerciseType.cardio: return widget.set.duration == 0 ? '' : widget.set.duration.toString();
      default: return '';
    }
  }

  void _save() {
    final v1Str = _col1Controller.text.trim();
    final v2Str = _col2Controller.text.trim();
    
    final v1 = double.tryParse(v1Str) ?? 0;
    final v2 = int.tryParse(v2Str) ?? 0;

    debugPrint('Saving Set: ${widget.exerciseName} - V1: $v1, V2: $v2');

    if (widget.exerciseName == 'Планка') {
      ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, duration: (v1 * 60).toInt());
      return;
    }

    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
      ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, reps: v1.toInt());
      return;
    }

    switch (widget.type) {
      case ExerciseType.strength:
        ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, weight: v1, reps: v2);
        break;
      case ExerciseType.bodyweight:
        ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, reps: v1.toInt());
        break;
      case ExerciseType.cardio:
        ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, distance: v1, duration: v2);
        break;
      case ExerciseType.static:
        ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, duration: (v1 * 60).toInt());
        break;
    }
  }

  bool _isValid() {
    final v1 = double.tryParse(_col1Controller.text.trim()) ?? 0;
    final v2 = int.tryParse(_col2Controller.text.trim()) ?? 0;

    if (widget.exerciseName == 'Планка') return v1 > 0;
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
      return v1 > 0;
    }

    switch (widget.type) {
      case ExerciseType.strength: return v1 > 0 && v2 > 0;
      case ExerciseType.bodyweight: return v1 > 0;
      case ExerciseType.cardio: return v1 > 0 && v2 > 0;
      case ExerciseType.static: return v1 > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _isValid();
    final bool showSecondField = (widget.type == ExerciseType.strength || widget.type == ExerciseType.cardio) && 
                                 widget.exerciseName != 'Планка' && 
                                 widget.exerciseCategory != 'Пресс' && 
                                 !['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${widget.setIndex + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: TextField(
              controller: _col1Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              decoration: InputDecoration(
                hintText: _getHint1(),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          
          if (showSecondField) ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _col2Controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _getHint2(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => _save(),
              ),
            ),
          ],

          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              widget.set.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 24,
              color: widget.set.isCompleted 
                  ? theme.colorScheme.primary 
                  : (isValid ? Colors.grey[400] : Colors.grey[800]),
            ),
            onPressed: () {
              if (widget.set.isCompleted) {
                HapticFeedback.lightImpact();
                ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, isCompleted: false);
              } else {
                if (!isValid) {
                  HapticFeedback.vibrate();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните обязательные поля')));
                  return;
                }
                HapticFeedback.mediumImpact();
                _save();
                ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, isCompleted: true);
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.grey),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(activeSessionProvider.notifier).removeSet(widget.entryIndex, widget.setIndex);
            },
          ),
        ],
      ),
    );
  }

  String _getHint1() {
    if (widget.exerciseName == 'Планка') return 'МИН';
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
      return 'ПОВТ';
    }
    switch (widget.type) {
      case ExerciseType.strength: return 'КГ';
      case ExerciseType.bodyweight: return 'ПОВТ';
      case ExerciseType.cardio: return 'КМ';
      case ExerciseType.static: return 'МИН';
    }
  }

  String _getHint2() {
    switch (widget.type) {
      case ExerciseType.strength: return 'ПОВТ';
      case ExerciseType.cardio: return 'МИН';
      default: return '';
    }
  }
}
