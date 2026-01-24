import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/progress_provider.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/exercise_selection_screen.dart';
import 'package:iron_log/ui/widgets/add_set_widget.dart';
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
    if (session == null || session.entries.isEmpty) {
      debugPrint('Validation Failed: Session is null or entries are empty');
      return false;
    }
    
    for (var i = 0; i < session.entries.length; i++) {
      final entry = session.entries[i];
      if (entry.sets.isEmpty) {
        debugPrint('Validation Failed: Entry ${entry.exerciseName} has no sets');
        return false;
      }
      for (var j = 0; j < entry.sets.length; j++) {
        final set = entry.sets[j];
        if (!set.isCompleted) {
          debugPrint('Validation Failed: Set ${j + 1} for ${entry.exerciseName} is not checked');
          return false;
        }

        bool isValid = false;
        final name = entry.exerciseName ?? '';
        final category = entry.exerciseCategory ?? '';

        if (name == 'Планка') {
           isValid = set.duration > 0;
        } else if (category == 'Пресс' || 
                  ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(name)) {
           isValid = set.reps > 0;
        } else {
          switch (entry.exerciseType) {
            case ExerciseType.strength:
              isValid = (set.weight >= 0) && set.reps > 0; // Allowing 0 weight for bodyweight-like strength moves
              break;
            case ExerciseType.bodyweight:
              isValid = set.reps > 0;
              break;
            case ExerciseType.cardio:
              isValid = set.duration > 0 && set.distance > 0;
              break;
            case ExerciseType.static:
              isValid = set.duration > 0;
              break;
          }
        }

        if (!isValid) {
          debugPrint('Validation Failed: ${entry.exerciseName} Set ${j + 1} incomplete: w=${set.weight}, r=${set.reps}, dur=${set.duration}');
          return false;
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
                    const SnackBar(content: Text('Заполните все данные и подтвердите подходы (чекбоксы)'))
                 );
                 return;
              }
              
              HapticFeedback.heavyImpact();
              
              final finalName = _nameController.text.trim();
              if (finalName.isNotEmpty) {
                 ref.read(activeSessionProvider.notifier).updateName(finalName);
              } else {
                 final now = DateTime.now();
                 ref.read(activeSessionProvider.notifier).updateName('Тренировка от ${DateFormat('dd.MM.yy').format(now)}');
              }
              
              try {
                await ref.read(activeSessionProvider.notifier).finishSession();
                
                // Success feedback
                _confettiController.play();
                
                // Force reactive reload
                ref.invalidate(historyProvider);
                ref.invalidate(progressStreamProvider);
                ref.invalidate(lastPerformanceProvider);
                
                Future.delayed(const Duration(milliseconds: 2000), () {
                  if (mounted) Navigator.pop(context);
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red),
                  );
                }
              }
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
          ...entry.sets.asMap().entries.map((e) => AddSetWidget(
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
