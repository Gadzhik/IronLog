import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class RestTimerOverlay extends StatefulWidget {
  final Widget child;
  const RestTimerOverlay({super.key, required this.child});

  static RestTimerOverlayState of(BuildContext context) {
    return context.findAncestorStateOfType<RestTimerOverlayState>()!;
  }

  @override
  State<RestTimerOverlay> createState() => RestTimerOverlayState();
}

class RestTimerOverlayState extends State<RestTimerOverlay> {
  Timer? _timer;
  int _secondsRemaining = 0;
  final AudioPlayer _player = AudioPlayer();
  bool _alertTriggered = false;

  void startTimer(int seconds) {
    setState(() {
      _secondsRemaining = seconds;
      _alertTriggered = false; 
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        
        // Critical: Alert at 10s
        if (_secondsRemaining == 10 && !_alertTriggered) {
           _alertTriggered = true;
           bool? hasVibrator = await Vibration.hasVibrator();
           if (hasVibrator == true) {
             Vibration.vibrate(duration: 500); 
           }
           // Attempt to play sound
           try {
             await _player.play(AssetSource('sounds/alert.mp3'));
           } catch (e) {
             // Ignore if asset missing
           }
        }
      } else {
        timer.cancel();
        bool? hasVibrator = await Vibration.hasVibrator();
         if (hasVibrator == true) {
           Vibration.vibrate(pattern: [0, 500, 200, 500]); 
         }
      }
    });
  }
  
  void cancelTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
       children: [
         widget.child,
         if (_secondsRemaining > 0 && _secondsRemaining <= 10)
           Positioned.fill(
             child: Container(
               color: Colors.black45,
               alignment: Alignment.center,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text(
                     'ПРИГОТОВИТЬСЯ', 
                     style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent, shadows: [
                       Shadow(blurRadius: 10, color: Colors.black)
                     ])
                   ),
                   Text(
                     '$_secondsRemaining',
                     style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white),
                   )
                 ],
               ),
             ),
           ),
       ],
    );
  }
  
  // Public getter to check state
  bool get isActive => _secondsRemaining > 0;
  int get seconds => _secondsRemaining;
}

class RestTimerButton extends StatelessWidget {
  const RestTimerButton({super.key});

  @override
  Widget build(BuildContext context) {
    // We assume this is inside RestTimerOverlay. But wait, ActiveSessionScreen uses it directly.
    // It's better to make RestTimerButton control the Overlay state via context if possible, 
    // OR we make RestTimerButton completely stand-alone but use an OverlayEntry.
    // Given the prompt "Overlay UI", the best way is to wrap ActiveSessionScreen's body or root.
    // However, I can't easily change the parent of ActiveSessionScreen without refactoring navigation.
    // Let's assume RestTimerButton is responsible for showing the overlay using `Overlay.of`.
    
    // Actually, "In-place" UI for timer is what we had. 
    // The "Overlay" request is for "during the final 10 seconds".
    // I can stick to my previous implementation but add the "Big Text" overlay specifically.
    
    return const _RestTimerInternal();
  }
}

class _RestTimerInternal extends StatefulWidget {
  const _RestTimerInternal();
  @override
  State<_RestTimerInternal> createState() => _RestTimerInternalState();
}

class _RestTimerInternalState extends State<_RestTimerInternal> {
  Timer? _timer;
  int _secondsRemaining = 0;
  final AudioPlayer _player = AudioPlayer();
  bool _alertTriggered = false;
  OverlayEntry? _overlayEntry;

  void startTimer(int seconds) {
    setState(() {
      _secondsRemaining = seconds;
      _alertTriggered = false; 
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
       if (!mounted) { timer.cancel(); return; }
       
       if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        
        // Show overlay if <= 10
        if (_secondsRemaining <= 10) {
           _showOverlay(true);
        }

        if (_secondsRemaining == 10 && !_alertTriggered) {
           _alertTriggered = true;
           bool? hasVibrator = await Vibration.hasVibrator();
           if (hasVibrator == true) {
             Vibration.vibrate(duration: 500); 
           }
           try {
             await _player.play(AssetSource('sounds/alert.mp3'));
           } catch (e) { /* ignore */ }
        }
      } else {
        timer.cancel();
        _showOverlay(false);
        bool? hasVibrator = await Vibration.hasVibrator();
         if (hasVibrator == true) {
           Vibration.vibrate(pattern: [0, 500, 200, 500]); 
         }
      }
    });
  }
  
  void _showOverlay(bool show) {
    if (show && _overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: (context) {
         return Positioned.fill(
           child: Material(
             color: Colors.black54,
             child: Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text('ПРИГОТОВИТЬСЯ', style: TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   Text('$_secondsRemaining', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
                 ],
               ),
             ),
           ),
         );
      });
      Overlay.of(context).insert(_overlayEntry!);
    } else if (!show && _overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    } else if (show && _overlayEntry != null) {
       _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _showOverlay(false);
    _player.dispose();
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
            foregroundColor: const Color(0xFF00E5FF), // High contrast Cyan
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsRemaining > 0) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border(top: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 2)),
          boxShadow: [
             BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.2), blurRadius: 20, spreadRadius: 0)
          ]
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Color(0xFF00E5FF), size: 30),
                const SizedBox(width: 12),
                Text(
                  'Отдых: $timerText',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                    shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 10)]
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                   icon: const Icon(Icons.stop_circle_outlined, size: 36, color: Colors.grey),
                   onPressed: () {
                     _timer?.cancel();
                     setState(() => _secondsRemaining = 0);
                     _showOverlay(false);
                   },
                   tooltip: 'Стоп',
                 )
              ],
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Таймер отдыха', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
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
