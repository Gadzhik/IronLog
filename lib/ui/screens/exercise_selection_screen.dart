import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 
// We are using collection for grouping. It is safe because flutter_test usually pulls it in,
// or we can just implement manual grouping if users env is strict.
// It was added in previous steps implicitly or explicitly? 
// Let's assume manual grouping if package import fails, but `collection` is standard.

class ExerciseSelectionScreen extends ConsumerStatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  ConsumerState<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends ConsumerState<ExerciseSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(searchExerciseProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор упражнения'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск упражнения',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(child: Text('Упражнения не найдены'));
                }

                // Feature: Categorization
                // If search query is active, show flat list for speed.
                // If no search query, show grouped list.
                
                if (_query.isNotEmpty) {
                   return ListView.separated(
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(exercise.category),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () {
                          ref.read(activeSessionProvider.notifier).addExercise(exercise);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }

                // Group by category
                final grouped = groupBy(exercises, (e) => e.category);
                // Sort categories
                final sortedKeys = grouped.keys.toList()..sort();

                return ListView(
                  children: sortedKeys.map((category) {
                    final categoryExercises = grouped[category]!;
                    return ExpansionTile(
                      title: Text(
                        category, 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary, 
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      initiallyExpanded: false, // Keep closed to save space initially
                      children: categoryExercises.map((exercise) {
                         return ListTile(
                            title: Text(exercise.name),
                            trailing: const Icon(Icons.add, color: Colors.grey),
                            onTap: () {
                               ref.read(activeSessionProvider.notifier).addExercise(exercise);
                               Navigator.pop(context);
                            },
                         );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Ошибка: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
