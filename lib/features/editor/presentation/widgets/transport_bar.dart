import 'package:flutter/material.dart';

import '../models/timeline_ruler_mode.dart';
import 'tempo_controls.dart';
import 'snap_control.dart';
import 'timeline_ruler_mode_control.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.isImporting,
    required this.positionSeconds,
    required this.rulerMode,
    required this.onPlayPressed,
    required this.onStopPressed,
    required this.onRulerModeChanged,
  });

  final bool isPlaying;
  final bool isImporting;
  final double positionSeconds;
  final TimelineRulerMode rulerMode;

  final VoidCallback onPlayPressed;
  final VoidCallback onStopPressed;
  final ValueChanged<TimelineRulerMode> onRulerModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Stop',
            onPressed: onStopPressed,
            icon: const Icon(Icons.stop),
          ),

          const SizedBox(width: 4),

          IconButton.filled(
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: onPlayPressed,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          ),

          const SizedBox(width: 24),

          Text(_formatTime(positionSeconds)),

          const SizedBox(width: 24),

          const TempoControls(),

          const SizedBox(width: 12),

          const SnapControl(),

          const SizedBox(width: 12),

          TimelineRulerModeControl(
            mode: rulerMode,
            onChanged: onRulerModeChanged,
          ),

          const Spacer(),

          if (isImporting)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Importing audio...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final totalMilliseconds = (seconds * 1000).floor();

    final minutes = totalMilliseconds ~/ 60000;

    final remainingMilliseconds = totalMilliseconds % 60000;

    final secs = remainingMilliseconds ~/ 1000;

    final millis = remainingMilliseconds % 1000;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}
