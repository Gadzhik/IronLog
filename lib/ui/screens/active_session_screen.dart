import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/exercise_selection_screen.dart';
import 'package:iron_log/ui/widgets/rest_timer.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  late ConfettiController _confettiController;
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
         _nameController.clear();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(activeSessionProvider);
      if (session != null) {
        _nameController.text = ""; 
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _isSessionValid(WorkoutSession? session) {
    if (session == null || session.entries.isEmpty) return false;
    
    for (var entry in session.entries) {
      if (entry.sets.isEmpty) return false;
      for (var set in entry.sets) {
        if (!set.isCompleted) return false;
        switch (entry.exerciseType) {
          case ExerciseType.strength:
            if (set.weight <= 0 || set.reps <= 0) return false;
            break;
          case ExerciseType.bodyweight:
            if (set.reps <= 0) return false;
            break;
          case ExerciseType.cardio:
            if (set.duration <= 0 || set.distance <= 0) return false;
            break;
          case ExerciseType.static:
            if (set.duration <= 0) return false;
            break;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool canFinish = _isSessionValid(session);

    return Scaffold(
      appBar: AppBar(
        title: Text('ТРЕНИРОВКА', style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.check, color: canFinish ? Theme.of(context).colorScheme.primary : Colors.grey),
            onPressed: () async {
              if (!canFinish) {
                 HapticFeedback.vibrate();
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все данные для завершения'))
                 );
                 return;
              }
              
              HapticFeedback.heavyImpact();
              _confettiController.play();
              
              if (_nameController.text.trim().isNotEmpty) {
                 ref.read(activeSessionProvider.notifier).updateName(_nameController.text);
              } else {
                 final now = DateTime.now();
                 ref.read(activeSessionProvider.notifier).updateName('Тренировка от ${DateFormat('dd.MM.yy').format(now)}');
              }
              
              await ref.read(activeSessionProvider.notifier).finishSession();
              
              Future.delayed(const Duration(milliseconds: 2000), () {
                if (mounted) Navigator.pop(context);
              });
            },
            tooltip: 'Завершить',
          )
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'НАЗВАНИЕ',
                    hintText: 'Моя тренировка',
                    hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(LucideIcons.edit3, size: 20),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: session.entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == session.entries.length) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: InkWell(
                          onTap: () {
                             HapticFeedback.lightImpact();
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()));
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.plus, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('ДОБАВИТЬ УПРАЖНЕНИЕ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return ExerciseEntryCard(
                      key: ValueKey('entry_${index}_${session.entries[index].exerciseId}'),
                      entryIndex: index, 
                      entry: session.entries[index]
                    );
                  },
                ),
              ),
              const RestTimerButton(),
            ],
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [Theme.of(context).colorScheme.primary, Colors.white, Colors.orange],
            gravity: 0.2,
          ),
        ],
      ),
    );
  }
}

class ExerciseEntryCard extends ConsumerWidget {
  final int entryIndex;
  final WorkoutEntry entry;

  const ExerciseEntryCard({super.key, required this.entryIndex, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPerfAsync = ref.watch(lastPerformanceProvider(entry.exerciseId ?? -1));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.exerciseName?.toUpperCase() ?? 'УПРАЖНЕНИЕ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.5,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.grey),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(activeSessionProvider.notifier).removeExercise(entryIndex);
                },
              )
            ],
          ),
          lastPerfAsync.when(
             data: (hint) => hint != null 
                ? Text('ПРОШЛЫЙ РАЗ: $hint', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.bold))
                : const SizedBox.shrink(),
             loading: () => const SizedBox.shrink(),
             error: (_,__) => const SizedBox.shrink()
          ),
          const SizedBox(height: 12),
          ...entry.sets.asMap().entries.map((e) => ExerciseSetRow(
            key: ValueKey('set_${entryIndex}_${e.key}'),
            entryIndex: entryIndex, 
            setIndex: e.key, 
            set: e.value, 
            type: entry.exerciseType,
            exerciseName: entry.exerciseName ?? '',
            exerciseCategory: entry.exerciseCategory ?? '',
          )),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(activeSessionProvider.notifier).addSet(entryIndex);
            },
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('ДОБАВИТЬ ПОДХОД', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class ExerciseSetRow extends ConsumerStatefulWidget {
  final int entryIndex;
  final int setIndex;
  final WorkoutSet set;
  final ExerciseType type;
  final String exerciseName;
  final String exerciseCategory;

  const ExerciseSetRow({
    super.key, 
    required this.entryIndex, 
    required this.setIndex, 
    required this.set, 
    required this.type,
    required this.exerciseName,
    required this.exerciseCategory,
  });

  @override
  ConsumerState<ExerciseSetRow> createState() => _ExerciseSetRowState();
}

class _ExerciseSetRowState extends ConsumerState<ExerciseSetRow> {
  late TextEditingController _col1Controller;
  late TextEditingController _col2Controller;

  @override
  void initState() {
    super.initState();
    _col1Controller = TextEditingController(text: _getInitialValue1());
    _col2Controller = TextEditingController(text: _getInitialValue2());
  }

  String _getInitialValue1() {
    // NAME-BASED LOGIC (STRICT)
    if (widget.exerciseName == 'Планка') {
       return widget.set.duration == 0 ? '' : (widget.set.duration ~/ 60).toString();
    }
    
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
       return widget.set.reps == 0 ? '' : widget.set.reps.toString();
    }

    switch (widget.type) {
      case ExerciseType.strength: return widget.set.weight == 0 ? '' : widget.set.weight.toInt().toString();
      case ExerciseType.bodyweight: return widget.set.reps == 0 ? '' : widget.set.reps.toString();
      case ExerciseType.cardio: return widget.set.distance == 0 ? '' : widget.set.distance.toInt().toString();
      case ExerciseType.static: return widget.set.duration == 0 ? '' : (widget.set.duration ~/ 60).toString();
    }
  }

  String _getInitialValue2() {
    if (widget.exerciseName == 'Планка') return '';
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
       return '';
    }

    switch (widget.type) {
      case ExerciseType.strength: return widget.set.reps == 0 ? '' : widget.set.reps.toString();
      case ExerciseType.bodyweight: return ''; 
      case ExerciseType.cardio: return widget.set.duration == 0 ? '' : widget.set.duration.toString();
      case ExerciseType.static: return ''; 
    }
  }

  void _save() {
     final v1 = double.tryParse(_col1Controller.text) ?? 0;
     final v2 = int.tryParse(_col2Controller.text) ?? 0;
     
     // NAME-BASED SAVE LOGIC
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

  @override
  Widget build(BuildContext context) {
    bool hasValue = false;
    
    // VALIDATION LOGIC (STRICT)
    if (widget.exerciseName == 'Планка') {
       hasValue = (double.tryParse(_col1Controller.text) ?? 0) > 0;
    } else if (widget.exerciseCategory == 'Пресс' || 
               ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
       hasValue = (int.tryParse(_col1Controller.text) ?? 0) > 0;
    } else {
      switch (widget.type) {
        case ExerciseType.strength:
          hasValue = (double.tryParse(_col1Controller.text) ?? 0) > 0 && (int.tryParse(_col2Controller.text) ?? 0) > 0;
          break;
        case ExerciseType.bodyweight:
          hasValue = (int.tryParse(_col1Controller.text) ?? 0) > 0;
          break;
        case ExerciseType.cardio:
          hasValue = (double.tryParse(_col1Controller.text) ?? 0) > 0 && (int.tryParse(_col2Controller.text) ?? 0) > 0;
          break;
        case ExerciseType.static:
          hasValue = (double.tryParse(_col1Controller.text) ?? 0) > 0;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${widget.setIndex + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(width: 8),
          
          // Field 1
          Expanded(
            child: TextField(
              controller: _col1Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              decoration: InputDecoration(
                hintText: _getHint1(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          
          // Field 2 (Optional/Type-based)
          if ((widget.type == ExerciseType.strength || widget.type == ExerciseType.cardio) && 
              widget.exerciseName != 'Планка' && 
              widget.exerciseCategory != 'Пресс' && 
              !['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) ...[
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _col2Controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                decoration: InputDecoration(
                  hintText: _getHint2(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                onChanged: (_) => _save(),
              ),
            ),
          ],

          // Special case for Bodyweight: Second field is Reps, but it's the PRIMARY field.
          // In the current architecture, Field 1 is used for Weight/Dist/Time.
          // Let's swap or clarify:
          // Strength: F1(KG), F2(REPS)
          // Cardio: F1(KM), F2(MIN)
          // Static: F1(SEC), no F2
          // Bodyweight: F1(REPS), no F2 (As per "ONLY Reps" requirement)

          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              widget.set.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 20,
              color: widget.set.isCompleted 
                  ? Theme.of(context).colorScheme.primary 
                  : (hasValue ? Colors.grey[400] : Colors.grey[800]),
            ),
            onPressed: () {
               if (widget.set.isCompleted) {
                  HapticFeedback.lightImpact();
                  ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, isCompleted: false);
               } else {
                  if (!hasValue) {
                     HapticFeedback.vibrate();
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните обязательные поля'))
                     );
                     return;
                  }
                  HapticFeedback.mediumImpact();
                  _save();
                  ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, isCompleted: true);
               }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.grey),
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
    if (widget.exerciseName == 'Планка') return '';
    if (widget.exerciseCategory == 'Пресс' || 
        ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(widget.exerciseName)) {
       return '';
    }

    switch (widget.type) {
      case ExerciseType.strength: return 'ПОВТ';
      case ExerciseType.bodyweight: return '';
      case ExerciseType.cardio: return 'МИН';
      case ExerciseType.static: return '';
    }
  }
}
