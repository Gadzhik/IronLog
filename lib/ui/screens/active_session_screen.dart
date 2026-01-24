import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:iron_log/providers.dart';
import 'package:iron_log/ui/screens/exercise_selection_screen.dart';
import 'package:iron_log/ui/widgets/rest_timer.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final _formKey = GlobalKey<FormState>();

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
        title: const Text('Текущая тренировка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Feature: GlobalKey Form Validation
              if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все обязательные поля!'))
                 );
                 return;
              }
              
              // Fallback logic check for empty sets not caught by form (if any)
              bool hasBroadlyInvalidSets = session.entries.any((e) => e.sets.any((s) => 
                 (e.exerciseType == ExerciseType.strength && (s.weight <= 0 && s.reps <= 0)) ||
                 (e.exerciseType == ExerciseType.cardio && (s.distance <= 0 && s.duration <= 0))
              ));
               
              if (hasBroadlyInvalidSets) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Проверьте пустые подходы!'))
                 );
                 return;
              }

              await ref.read(activeSessionProvider.notifier).finishSession();
              if (context.mounted) Navigator.pop(context);
            },
            tooltip: 'Завершить',
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                initialValue: session.name,
                decoration: const InputDecoration(
                  labelText: 'Название тренировки',
                  prefixIcon: Icon(Icons.edit),
                ),
                onChanged: (val) {
                  ref.read(activeSessionProvider.notifier).updateName(val);
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                 child: Column(
                   children: [
                     ...List.generate(session.entries.length + 1, (index) {
                        if (index == session.entries.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                 Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить упражнение'),
                            ),
                          );
                        }
                        
                        final entry = session.entries[index];
                        return ExerciseEntryCard(entryIndex: index, entry: entry);
                     }),
                     const SizedBox(height: 100), // Space for timer
                   ],
                 ),
              ),
            ),
            const RestTimerButton(),
          ],
        ),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.exerciseName ?? 'Упражнение',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                     ref.read(activeSessionProvider.notifier).removeExercise(entryIndex);
                  },
                )
              ],
            ),
            
            lastPerfAsync.when(
               data: (hint) => hint != null 
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Прошлый раз: $hint', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    )
                  : const SizedBox.shrink(),
               loading: () => const SizedBox.shrink(),
               error: (_,__) => const SizedBox.shrink()
            ),

            const SizedBox(height: 8),
             Row(
              children: [
                Expanded(child: Text(isCardio ? 'Дистанция (км)' : 'Вес (кг)', style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(width: 8),
                Expanded(child: Text(isCardio ? 'Время (мин)' : 'Повт.', style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(width: 48), 
              ],
            ),
            const SizedBox(height: 8),
            ...entry.sets.asMap().entries.map((e) {
              final setIndex = e.key;
              final set = e.value;
              return ExerciseSetRow(
                entryIndex: entryIndex, 
                setIndex: setIndex, 
                set: set, 
                isCardio: isCardio,
                onComplete: () {
                   // Optional: Start timer
                }
              );
            }),
            TextButton(
              onPressed: () {
                ref.read(activeSessionProvider.notifier).addSet(entryIndex);
              },
              child: const Text('+ Добавить подход'),
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
  final VoidCallback onComplete;

  const ExerciseSetRow({
    super.key, 
    required this.entryIndex, 
    required this.setIndex, 
    required this.set, 
    required this.isCardio,
    required this.onComplete,
  });

  @override
  ConsumerState<ExerciseSetRow> createState() => _ExerciseSetRowState();
}

class _ExerciseSetRowState extends ConsumerState<ExerciseSetRow> {
  late TextEditingController _col1Controller;
  late TextEditingController _col2Controller;
  final FocusNode _col1Focus = FocusNode();
  final FocusNode _col2Focus = FocusNode();

  @override
  void initState() {
    super.initState();
    
    String text1 = _valToStr(widget.isCardio ? widget.set.distance : widget.set.weight);
    String text2 = _valToStr(widget.isCardio ? widget.set.duration : widget.set.reps);

    _col1Controller = TextEditingController(text: text1);
    _col2Controller = TextEditingController(text: text2);
    
    _col1Focus.addListener(() {
      if (_col1Focus.hasFocus) {
        final text = _col1Controller.text;
        if (text == '' || text == '0' || text == '0.0') {
           _col1Controller.clear();
        }
      }
    });
    
    _col2Focus.addListener(() {
      if (_col2Focus.hasFocus) {
         final text = _col2Controller.text;
         if (text == '' || text == '0') {
            _col2Controller.clear();
         }
      }
    });
  }
  
  String _valToStr(num val) {
     return val == 0 ? '' : val.toString();
  }
  
  @override
  void didUpdateWidget(covariant ExerciseSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.set != oldWidget.set) {
      if (!_col1Focus.hasFocus) {
          _col1Controller.text = _valToStr(widget.isCardio ? widget.set.distance : widget.set.weight);
      }
      if (!_col2Focus.hasFocus) {
         _col2Controller.text = _valToStr(widget.isCardio ? widget.set.duration : widget.set.reps);
      }
    }
  }

  @override
  void dispose() {
    _col1Controller.dispose();
    _col2Controller.dispose();
    _col1Focus.dispose();
    _col2Focus.dispose();
    super.dispose();
  }

  void _save() {
     final val1 = double.tryParse(_col1Controller.text) ?? 0;
     final val2 = int.tryParse(_col2Controller.text) ?? 0;
     
     if (widget.isCardio) {
       ref.read(activeSessionProvider.notifier).updateSet(
         widget.entryIndex, widget.setIndex, distance: val1, duration: val2
       );
     } else {
       ref.read(activeSessionProvider.notifier).updateSet(
         widget.entryIndex, widget.setIndex, weight: val1, reps: val2
       );
     }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (focused) {
                if (!focused) _save();
              },
              child: TextFormField(
                controller: _col1Controller,
                focusNode: _col1Focus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true, 
                  contentPadding: const EdgeInsets.all(8),
                  hintText: '0', 
                  hintStyle: TextStyle(color: Colors.grey[600])
                ),
                validator: (val) {
                   if (val == null || val.isEmpty || val == '0') return '!';
                   return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: (focused) {
                 if (!focused) _save();
              },
              child: TextFormField(
                controller: _col2Controller,
                focusNode: _col2Focus,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true, 
                  contentPadding: const EdgeInsets.all(8),
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.grey[600])
                ),
                validator: (val) {
                   if (val == null || val.isEmpty || val == '0') return '!';
                   return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              widget.set.isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: widget.set.isCompleted ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              bool newVal = !widget.set.isCompleted;
              if (newVal) {
                 final val1 = double.tryParse(_col1Controller.text) ?? 0;
                 final val2 = int.tryParse(_col2Controller.text) ?? 0;
                 if (val1 <= 0 && val2 <= 0) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите данные!')));
                     return;
                 }
                 _save();
              }
              
              ref.read(activeSessionProvider.notifier).updateSet(
                   widget.entryIndex, widget.setIndex, isCompleted: newVal
              );
              if (newVal) widget.onComplete();
            },
          ),
          IconButton(
             icon: const Icon(Icons.close, size: 16),
             onPressed: () {
                ref.read(activeSessionProvider.notifier).removeSet(widget.entryIndex, widget.setIndex);
             },
          )
        ],
      ),
    );
  }
}
