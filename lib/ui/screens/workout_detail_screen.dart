import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // Read-only view
    final dateStr = DateFormat('d MMMM yyyy, HH:mm', 'ru').format(session.startTime);
    final duration = session.endTime != null 
        ? session.endTime!.difference(session.startTime).inMinutes 
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name ?? 'Тренировка'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
             child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text('Дата: $dateStr', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    if (duration > 0)
                      Text('Длительность: $duration мин', style: const TextStyle(fontSize: 16)),
                    if (session.note != null && session.note!.isNotEmpty)
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Text('Заметка: ${session.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
                       ),
                 ],
               ),
             ),
          ),
          const SizedBox(height: 16),
          const Text('Упражнения', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...session.entries.map((entry) {
             final isCardio = entry.exerciseType == ExerciseType.cardio;
             return Card(
               margin: const EdgeInsets.only(bottom: 12),
               child: Padding(
                 padding: const EdgeInsets.all(12),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       entry.exerciseName ?? 'Упражнение',
                       style: TextStyle(
                         fontSize: 18, 
                         fontWeight: FontWeight.bold,
                         color: Theme.of(context).colorScheme.primary,
                       ),
                     ),
                     const SizedBox(height: 12),
                     // Table Header
                     Row(
                       children: [
                         SizedBox(width: 30, child: Text('#', style: TextStyle(color: Colors.grey[600]))),
                         Expanded(child: Text(isCardio ? 'Дистанция' : 'Вес', style: TextStyle(color: Colors.grey[600]))),
                         Expanded(child: Text(isCardio ? 'Время' : 'Повторы', style: TextStyle(color: Colors.grey[600]))),
                       ],
                     ),
                     const Divider(),
                     const SizedBox(height: 4),
                     // Sets
                     ...entry.sets.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final s = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                             children: [
                               SizedBox(width: 30, child: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold))),
                               // Feature: Integer Formatting
                               Expanded(child: Text(isCardio 
                                  ? '${s.distance % 1 == 0 ? s.distance.toInt() : s.distance} км' 
                                  : '${s.weight % 1 == 0 ? s.weight.toInt() : s.weight} кг')),
                               Expanded(child: Text(isCardio 
                                  ? '${s.duration} с' 
                                  : '${s.reps}')),
                             ],
                          ),
                        );
                     }),
                   ],
                 ),
               ),
             );
          }).toList(),
        ],
      ),
    );
  }
}
