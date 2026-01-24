import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; 

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
    _searchController.addListener(() => setState(() => _query = _searchController.text));
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
                hintText: 'Поиск...',
                prefixIcon: Icon(LucideIcons.search, size: 20),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)));
                }

                final grouped = groupBy(exercises, (e) => e.category);
                final sortedKeys = grouped.keys.toList()..sort();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: sortedKeys.map((category) {
                    final categoryExercises = grouped[category]!;
                    return ExpansionTile(
                      leading: Icon(_getCategoryIcon(category), size: 18, color: Theme.of(context).colorScheme.primary),
                      title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                      initiallyExpanded: _query.isNotEmpty,
                      children: categoryExercises.map((exercise) {
                         return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                            title: Text(exercise.name),
                            trailing: const Icon(LucideIcons.plus, size: 16, color: Colors.grey),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'грудь': return LucideIcons.circleDot;
      case 'спина': return LucideIcons.layers;
      case 'ноги': return LucideIcons.footprints;
      case 'кардио': return LucideIcons.heartPulse;
      case 'руки': return LucideIcons.armchair; // Placeholder
      case 'плечи': return LucideIcons.moveUp;
      default: return LucideIcons.dumbbell;
    }
  }
}
