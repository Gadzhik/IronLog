import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/exercise_selection_screen.dart';
import 'package:iron_log/ui/widgets/rest_timer.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:confetti/confetti.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      // Fix: Requirement to NOT show "No active workout" here if it's redundant.
      // Returning just a loader or empty container to avoid ghosting.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ТРЕНИРОВКА'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.check),
            onPressed: () async {
              if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                 HapticFeedback.vibrate();
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните данные!'))
                 );
                 return;
              }
              
              HapticFeedback.heavyImpact(); // Requirement: Heavy on save
              _confettiController.play();
              
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
          Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: TextFormField(
                      initialValue: session.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        prefixIcon: Icon(LucideIcons.edit3, size: 20),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => ref.read(activeSessionProvider.notifier).updateName(val),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: session.entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == session.entries.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: InkWell(
                            onTap: () {
                               HapticFeedback.lightImpact(); // Requirement: light on tap
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()));
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
                                  Text(
                                    'Добавить упражнение', 
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return ExerciseEntryCard(
                        key: ValueKey('entry_${session.entries[index].exerciseId}_$index'),
                        entryIndex: index, 
                        entry: session.entries[index]
                      );
                    },
                  ),
                ),
                const RestTimerButton(),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            gravity: 0.1,
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
    final isCardio = entry.exerciseType == ExerciseType.cardio;
    final lastPerfAsync = ref.watch(lastPerformanceProvider(entry.exerciseId ?? -1));
    final bool canAddSet = entry.sets.isEmpty || entry.sets.last.isCompleted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Hero(
                  tag: 'ex_${entry.exerciseId}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      entry.exerciseName ?? 'Упражнение',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.grey),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(activeSessionProvider.notifier).removeExercise(entryIndex);
                },
              )
            ],
          ),
          lastPerfAsync.when(
             data: (hint) => hint != null 
                ? Text('Прошлый раз: $hint', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))
                : const SizedBox.shrink(),
             loading: () => const SizedBox.shrink(),
             error: (_,__) => const SizedBox.shrink()
          ),
          const SizedBox(height: 16),
          ...entry.sets.asMap().entries.map((e) => ExerciseSetRow(
            key: ValueKey('set_${entryIndex}_${e.key}'),
            entryIndex: entryIndex, 
            setIndex: e.key, 
            set: e.value, 
            isCardio: isCardio,
          )),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: canAddSet ? () {
              HapticFeedback.lightImpact();
              ref.read(activeSessionProvider.notifier).addSet(entryIndex);
            } : null,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Добавить подход'),
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
  final bool isCardio;

  const ExerciseSetRow({
    super.key, 
    required this.entryIndex, 
    required this.setIndex, 
    required this.set, 
    required this.isCardio,
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
    _col1Controller = TextEditingController(text: _format(widget.isCardio ? widget.set.distance : widget.set.weight));
    _col2Controller = TextEditingController(text: _format(widget.isCardio ? widget.set.duration : widget.set.reps));
  }

  String _format(num val) => val == 0 ? '' : (val % 1 == 0 ? val.toInt().toString() : val.toString());

  void _save() {
     final v1 = double.tryParse(_col1Controller.text) ?? 0;
     final v2 = int.tryParse(_col2Controller.text) ?? 0;
     if (widget.isCardio) {
       ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, distance: v1, duration: v2);
     } else {
       ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, weight: v1, reps: v2);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.setIndex + 1}', 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).colorScheme.primary
              )
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _col1Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: widget.isCardio ? 'км' : 'кг',
                  hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  _save();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _col2Controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: widget.isCardio ? 'мин' : 'повт',
                  hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  _save();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              widget.set.isCompleted ? LucideIcons.checkSquare : LucideIcons.square,
              color: widget.set.isCompleted ? Theme.of(context).colorScheme.primary : Colors.grey[400],
            ),
            onPressed: () {
               HapticFeedback.mediumImpact();
               _save();
               ref.read(activeSessionProvider.notifier).updateSet(
                 widget.entryIndex, 
                 widget.setIndex, 
                 isCompleted: !widget.set.isCompleted
               );
            },
          ),
          IconButton(
             icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
             onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(activeSessionProvider.notifier).removeSet(widget.entryIndex, widget.setIndex);
             },
          )
        ],
      ),
    );
  }
}
