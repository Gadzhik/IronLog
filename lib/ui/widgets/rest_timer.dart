import 'dart:async';
import 'package:flutter/material.dart';

class RestTimerButton extends StatefulWidget {
  const RestTimerButton({super.key});

  @override
  State<RestTimerButton> createState() => _RestTimerButtonState();
}

class _RestTimerButtonState extends State<RestTimerButton> {
  Timer? _timer;
  int _secondsRemaining = 0;

  void startTimer() {
    setState(() {
      _secondsRemaining = 90;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get timerText {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsRemaining > 0) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, color: Colors.deepOrange),
            const SizedBox(width: 12),
            Text(
              'Отдых: $timerText',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
               icon: const Icon(Icons.skip_next),
               onPressed: () {
                 _timer?.cancel();
                 setState(() => _secondsRemaining = 0);
               },
               tooltip: 'Пропустить',
             )
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: startTimer,
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Отдых 90 сек'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2E),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
