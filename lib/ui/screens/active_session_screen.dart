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
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Map to store FocusNodes for each exercise entry index
  final Map<int, FocusNode> _focusNodes = {};
  int _prevEntryCount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Validation Listener
    _nameController.addListener(() {
      setState(() {});
    });
    
    // Default Name Logic
    final now = DateTime.now();
    final defaultName = 'Тренинг ${DateFormat('dd.MM.yy-HH.mm.ss').format(now)}';
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(activeSessionProvider);
      if (session != null) {
        if (session.name == null || session.name!.isEmpty) {
           _nameController.text = defaultName;
           ref.read(activeSessionProvider.notifier).updateName(defaultName);
        } else {
           _nameController.text = session.name!; 
        }
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    for (var node in _focusNodes.values) node.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return; 

    if (!mounted) return;
    
    // 1. Set Loading
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      // 2. Update Name
      ref.read(activeSessionProvider.notifier).updateName(name);

      // 3. Save (Fail-Safe)
      await ref.read(activeSessionProvider.notifier).finishSession();

      // 4. Invalidate
      ref.invalidate(historyProvider);
      ref.invalidate(progressStreamProvider);
      
      // 5. Confetti
      _confettiController.play();

      // 6. Success Navigation
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 2000));
      
      if (mounted) {
         Navigator.pop(context); 
      }

    } catch (e) {
      debugPrint("SAVE ERROR: $e");
      if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red),
           );
      }
    } finally {
      // 7. MANDATORY Finalization
      if (mounted) {
         setState(() => _isSaving = false);
      }
    }
  }

  bool _isSessionValid(WorkoutSession? session) {
    if (session == null || session.entries.isEmpty) return false;
    
    for (var entry in session.entries) {
      if (entry.sets.isEmpty) return false;
      for (var set in entry.sets) {
        if (!set.isCompleted) return false;
        
        bool isValid = false;
        final name = entry.exerciseName ?? '';
        final category = entry.exerciseCategory ?? '';

        if (name.contains('Планка') || entry.exerciseType == ExerciseType.static) {
           isValid = set.duration > 0;
        } else if (category.contains('Пресс') || 
                  name.contains('Книжка') ||
                  ['Гиперэкстензия', 'Подтягивания', 'Отжимания от скамьи', 'Отжимания на брусьях'].contains(name)) {
           isValid = set.reps > 0;
        } else {
          switch (entry.exerciseType) {
            case ExerciseType.strength:
              isValid = set.reps > 0; // Allowing 0 weight for bodyweight-like moves
              break;
            case ExerciseType.bodyweight:
              isValid = set.reps > 0;
              break;
            case ExerciseType.cardio:
              isValid = set.duration > 0 && set.distance > 0;
              break;
            default:
              isValid = false;
          }
        }
        if (!isValid) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Focus Management Logic
    final currentCount = session.entries.length;
    if (currentCount > _prevEntryCount) {
       // A new exercise was added
       final newIndex = currentCount - 1;
       _focusNodes[newIndex] = FocusNode();
       
       WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNodes[newIndex]?.requestFocus();
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
       });
    }
    _prevEntryCount = currentCount;

    final bool canFinish = _isSessionValid(session);

    return Scaffold(
      appBar: AppBar(
        title: Text('ТРЕНИРОВКА', style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 2)),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (context, value, child) {
              final isNameValid = value.text.trim().isNotEmpty;
              final bool isReady = canFinish && isNameValid && !_isSaving;

              return IconButton(
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(LucideIcons.check, color: isReady ? Theme.of(context).colorScheme.primary : Colors.grey),
                onPressed: isReady ? _saveWorkout : null,
                tooltip: 'Завершить',
              );
            },
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
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'НАЗВАНИЕ ТРЕНИРОВКИ',
                    prefixIcon: Icon(LucideIcons.edit3, size: 20),
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    hintText: 'Название тренировки (напр. Спина и Бицепс)',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: session.entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == session.entries.length) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: InkWell(
                          onTap: () {
                             if (_isSaving) return;
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
                      entry: session.entries[index],
                      isSaving: _isSaving,
                      focusNode: _focusNodes[index], // Pass the focus node
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
  final bool isSaving;
  final FocusNode? focusNode;

  const ExerciseEntryCard({super.key, required this.entryIndex, required this.entry, required this.isSaving, this.focusNode});

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
              if (!isSaving)
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
            // Pass focus node only to the first set of the newly added exercise
            focusNode: (e.key == 0) ? focusNode : null,
          )),
          const SizedBox(height: 8),
          if (!isSaving)
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
