import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_log/data/models/exercise.dart';
import 'package:iron_log/data/models/workout_session.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

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
        title: Text(session.name?.toUpperCase() ?? 'ДЕТАЛИ ТРЕНИРОВКИ', style: GoogleFonts.bebasNeue(fontSize: 32, letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surface,
               borderRadius: BorderRadius.circular(24),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  _InfoRow(icon: LucideIcons.calendar, label: 'ДАТА', value: dateStr.toUpperCase()),
                  if (duration > 0) ...[
                    const SizedBox(height: 16),
                    _InfoRow(icon: LucideIcons.clock, label: 'ВРЕМЯ', value: '$duration МИН'),
                  ],
                  if (session.note != null && session.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoRow(icon: LucideIcons.fileText, label: 'ЗАМЕТКА', value: session.note!.toUpperCase()),
                  ],
               ],
             ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            child: Text('УПРАЖНЕНИЯ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          ...session.entries.map((entry) => _ExerciseDetailCard(entry: entry)).toList(),
          const SizedBox(height: 48),
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
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.exerciseName?.toUpperCase() ?? 'УПРАЖНЕНИЕ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeaderCell(label: '#', width: 30),
              _HeaderCell(label: isCardio ? 'ДИСТАНЦИЯ' : 'ВЕС', expanded: true),
              _HeaderCell(label: isCardio ? 'ВРЕМЯ' : 'ПОВТ', expanded: true),
            ],
          ),
          const SizedBox(height: 12),
          ...entry.sets.asMap().entries.map((e) {
               final i = e.key + 1;
               final s = e.value;
               String f(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

               final isBodyweight = ['Книжка', 'Гиперэкстензия', 'Подтягивания', 'Отжимания на брусьях', 'Отжимания от скамьи'].any((el) => entry.exerciseName?.contains(el) ?? false) || (entry.exerciseCategory?.contains('Пресс') ?? false);
               final isPlank = entry.exerciseName?.contains('Планка') ?? false;

               if (isPlank) {
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Row(
                      children: [
                        SizedBox(width: 30, child: Text('$i', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).hintColor, fontSize: 12))),
                        Expanded(child: Text('-', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('${f(s.duration / 60)} МИН', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                   ),
                 );
               } else if (isBodyweight) {
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Row(
                      children: [
                        SizedBox(width: 30, child: Text('$i', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).hintColor, fontSize: 12))),
                        Expanded(child: Text('-', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('${f(s.reps)} ПОВТ', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                   ),
                 );
               }
               
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: Row(
                    children: [
                      SizedBox(width: 30, child: Text('$i', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).hintColor, fontSize: 12))),
                      Expanded(child: Text('${f(isCardio ? s.distance : s.weight)} ${isCardio ? 'КМ' : 'КГ'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('${f(isCardio ? s.duration : s.reps)} ${isCardio ? 'МИН' : ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                 ),
               );
          }),
        ],
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
    final child = Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Theme.of(context).hintColor, letterSpacing: 1));
    if (expanded) return Expanded(child: child);
    return SizedBox(width: width, child: child);
  }
}
