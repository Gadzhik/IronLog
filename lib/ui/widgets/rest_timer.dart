import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:iron_log/ui/app_theme.dart';

class RestTimerButton extends ConsumerWidget {
  const RestTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _RestTimerInternal();
  }
}

class _RestTimerInternal extends ConsumerStatefulWidget {
  const _RestTimerInternal();
  @override
  ConsumerState<_RestTimerInternal> createState() => _RestTimerInternalState();
}

class _RestTimerInternalState extends ConsumerState<_RestTimerInternal> {
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
        
        if (_secondsRemaining <= 10) {
           _showOverlay(true);
        }

        if (_secondsRemaining <= 10 && !_alertTriggered) {
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (show && _overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: (context) {
         return Positioned.fill(
           child: Material(
             color: Colors.black87,
             child: Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     'ПРИГОТОВИТЬСЯ', 
                     style: TextStyle(
                       color: primaryColor, 
                       fontSize: 42, 
                       fontWeight: FontWeight.w900,
                       letterSpacing: 2,
                       shadows: [Shadow(color: primaryColor.withOpacity(0.5), blurRadius: 20)]
                     )
                   ),
                   const SizedBox(height: 32),
                   Text(
                     '$_secondsRemaining', 
                     style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)
                   ),
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
  
  Widget _buildPresetButton(String label, int seconds, Color primary) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          onPressed: () => startTimer(seconds),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: primary,
            side: BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (_secondsRemaining > 0) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: primary.withOpacity(0.5), width: 2)),
          boxShadow: [
             BoxShadow(color: primary.withOpacity(0.2), blurRadius: 20, spreadRadius: 0)
          ]
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: primary, size: 30),
                const SizedBox(width: 16),
                Text(
                  'ОТДЫХ: $timerText',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: primary,
                    letterSpacing: 1,
                    shadows: [Shadow(color: primary.withOpacity(0.5), blurRadius: 10)]
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                   icon: const Icon(Icons.stop_circle_rounded, size: 36, color: Colors.grey),
                   onPressed: () {
                     _timer?.cancel();
                     setState(() => _secondsRemaining = 0);
                     _showOverlay(false);
                   },
                 )
              ],
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ТАЙМЕР ОТДЫХА', style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPresetButton('30С', 30, primary),
              _buildPresetButton('60С', 60, primary),
              _buildPresetButton('2М', 120, primary),
              _buildPresetButton('5М', 300, primary),
            ],
          ),
        ],
      ),
    );
  }
}
