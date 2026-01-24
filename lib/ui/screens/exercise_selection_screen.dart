import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_log/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
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
        title: Text('ВЫБОР УПРАЖНЕНИЯ', style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ПОИСК...',
                prefixIcon: Icon(LucideIcons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(child: Text('НИЧЕГО НЕ НАЙДЕНО', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
                }

                final grouped = groupBy(exercises, (e) => e.category);
                final sortedKeys = grouped.keys.toList()..sort();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: sortedKeys.map((category) {
                    final categoryExercises = grouped[category]!;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        leading: Icon(_getCategoryIcon(category), size: 18, color: Theme.of(context).colorScheme.primary),
                        title: Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                        initiallyExpanded: _query.isNotEmpty,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                        children: categoryExercises.map((exercise) {
                           return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                              title: Text(exercise.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              trailing: const Icon(LucideIcons.plus, size: 16, color: Colors.grey),
                              onTap: () {
                                 ref.read(activeSessionProvider.notifier).addExercise(exercise);
                                 Navigator.pop(context);
                              },
                           );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('ОШИБКА: $err')),
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
      case 'плечи': return LucideIcons.moveUp;
      case 'руки': return LucideIcons.dumbbell;
      default: return LucideIcons.dumbbell;
    }
  }
}
