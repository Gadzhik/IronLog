import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:lucide_icons/lucide_icons.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutSession session;
  const WorkoutDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMMM yyyy, HH:mm', 'ru').format(session.startTime);
    final duration = session.endTime != null 
        ? session.endTime!.difference(session.startTime).inMinutes 
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name?.isNotEmpty == true ? session.name! : 'Детали тренировки'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
             child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    _InfoRow(icon: LucideIcons.calendar, label: 'Дата', value: dateStr),
                    if (duration > 0) ...[
                      const SizedBox(height: 12),
                      _InfoRow(icon: LucideIcons.clock, label: 'Время', value: '$duration мин'),
                    ],
                    if (session.note != null && session.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoRow(icon: LucideIcons.fileText, label: 'Заметка', value: session.note!),
                    ],
                 ],
               ),
             ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Text('Упражнения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...session.entries.map((entry) => _ExerciseDetailCard(entry: entry)).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  final WorkoutEntry entry;
  const _ExerciseDetailCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCardio = entry.exerciseType == ExerciseType.cardio;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.exerciseName ?? 'Упражнение',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _HeaderCell(label: '#', width: 30),
                _HeaderCell(label: isCardio ? 'Дистанция' : 'Вес', expanded: true),
                _HeaderCell(label: isCardio ? 'Время' : 'Повт', expanded: true),
              ],
            ),
            const Divider(height: 24),
            ...entry.sets.asMap().entries.map((e) {
               final i = e.key + 1;
               final s = e.value;
               String f(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
               
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 6.0),
                 child: Row(
                    children: [
                      SizedBox(width: 30, child: Text('$i', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).hintColor))),
                      Expanded(child: Text('${f(isCardio ? s.distance : s.weight)} ${isCardio ? 'км' : 'кг'}')),
                      Expanded(child: Text('${f(isCardio ? s.duration : s.reps)} ${isCardio ? 'с' : ''}')),
                    ],
                 ),
               );
            }),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  final bool expanded;
  const _HeaderCell({required this.label, this.width, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final child = Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor));
    if (expanded) return Expanded(child: child);
    return SizedBox(width: width, child: child);
  }
}
