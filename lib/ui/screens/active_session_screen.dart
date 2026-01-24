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
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
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
      return const Scaffold(
        body: Center(child: Text("Нет активной тренировки")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.check),
            onPressed: () async {
              if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните данные!'))
                 );
                 return;
              }
              
              HapticFeedback.mediumImpact();
              _confettiController.play();
              
              await ref.read(activeSessionProvider.notifier).finishSession();
              
              Future.delayed(const Duration(milliseconds: 1500), () {
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextFormField(
                    initialValue: session.name,
                    decoration: const InputDecoration(
                      labelText: 'Название тренировки',
                      prefixIcon: Icon(LucideIcons.edit3, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (val) => ref.read(activeSessionProvider.notifier).updateName(val),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: session.entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == session.entries.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: OutlinedButton.icon(
                            onPressed: () {
                               HapticFeedback.lightImpact();
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()));
                            },
                            icon: const Icon(LucideIcons.plus),
                            label: const Text('Добавить упражнение'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      }
                      return ExerciseEntryCard(entryIndex: index, entry: session.entries[index]);
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
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Colors.green,
              Colors.blue,
              Colors.pink,
            ],
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

    // Logic for "Add Set" button disabling
    final bool canAddSet = entry.sets.isEmpty || entry.sets.last.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.exerciseName ?? 'Упражнение',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.grey),
                  onPressed: () => ref.read(activeSessionProvider.notifier).removeExercise(entryIndex),
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
  final FocusNode _f1 = FocusNode();
  final FocusNode _f2 = FocusNode();

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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text('${widget.setIndex + 1}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _col1Controller,
              focusNode: _f1,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: widget.isCardio ? 'км' : 'кг',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _col2Controller,
              focusNode: _f2,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: widget.isCardio ? 'мин' : 'повт',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              widget.set.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: widget.set.isCompleted ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            onPressed: () {
               HapticFeedback.mediumImpact();
               _save();
               ref.read(activeSessionProvider.notifier).updateSet(widget.entryIndex, widget.setIndex, isCompleted: !widget.set.isCompleted);
            },
          ),
          IconButton(
             icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
             onPressed: () => ref.read(activeSessionProvider.notifier).removeSet(widget.entryIndex, widget.setIndex),
          )
        ],
      ),
    );
  }
}
