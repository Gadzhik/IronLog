import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class RestTimerButton extends StatefulWidget {
  const RestTimerButton({super.key});

  @override
  State<RestTimerButton> createState() => _RestTimerButtonState();
}

class _RestTimerButtonState extends State<RestTimerButton> {
  Timer? _timer;
  int _secondsRemaining = 0;
  
  // Feature: Pre-End Alert
  bool _alertTriggered = false;

  void startTimer(int seconds) {
    setState(() {
      _secondsRemaining = seconds;
      _alertTriggered = false; // Reset alert
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        
        // Feature: Pre-finish Alert (10 seconds)
        if (_secondsRemaining == 10 && !_alertTriggered) {
           _alertTriggered = true;
           bool? hasVibrator = await Vibration.hasVibrator();
           if (hasVibrator == true) {
             Vibration.vibrate(duration: 500); // 500ms vibration
           }
        }
      } else {
        timer.cancel();
        // Vibrate on finish too? Maybe double vibe.
        bool? hasVibrator = await Vibration.hasVibrator();
         if (hasVibrator == true) {
           Vibration.vibrate(pattern: [0, 200, 100, 200]); 
         }
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

  Widget _buildPresetButton(String label, int seconds) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          onPressed: () => startTimer(seconds),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsRemaining > 0) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.deepOrange),
                const SizedBox(width: 12),
                Text(
                  'Отдых: $timerText',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                   icon: const Icon(Icons.stop_circle_outlined, size: 32, color: Colors.grey),
                   onPressed: () {
                     _timer?.cancel();
                     setState(() => _secondsRemaining = 0);
                   },
                   tooltip: 'Стоп',
                 )
              ],
            ),
            const SizedBox(height: 8),
            const Text('+10 сек', style: TextStyle(color: Colors.white24, fontSize: 10)),
            // Optional: Tap on timer increases time?
          ],
        ),
      );
    }
    
    // Feature: Presets UI
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Таймер отдыха', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPresetButton('30с', 30),
              _buildPresetButton('60с', 60),
              _buildPresetButton('2м', 120),
              _buildPresetButton('5м', 300),
            ],
          ),
        ],
      ),
    );
  }
}
