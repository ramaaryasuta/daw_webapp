import 'package:flutter/material.dart';

import '../models/timeline_ruler_mode.dart';
import '../controllers/audio_meter_controller.dart';
import 'audio_level_meter.dart';
import 'tempo_controls.dart';
import 'snap_control.dart';
import 'timeline_ruler_mode_control.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.isImporting,
    required this.isLoopEnabled,
    required this.positionSeconds,
    required this.rulerMode,
    required this.onPlayPressed,
    required this.onStopPressed,
    required this.onLoopPressed,
    required this.onRulerModeChanged,
    this.meterController,
  });

  final bool isPlaying;
  final bool isImporting;
  final bool isLoopEnabled;
  final double positionSeconds;
  final TimelineRulerMode rulerMode;
  final AudioMeterController? meterController;

  final VoidCallback onPlayPressed;
  final VoidCallback onStopPressed;
  final VoidCallback onLoopPressed;
  final ValueChanged<TimelineRulerMode> onRulerModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Stop',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: onStopPressed,
                    icon: const Icon(Icons.stop, size: 20),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: onPlayPressed,
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Loop playback',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    isSelected: isLoopEnabled,
                    onPressed: onLoopPressed,
                    icon: const Icon(Icons.repeat, size: 20),
                    selectedIcon: const Icon(Icons.repeat, size: 20),
                    style: isLoopEnabled
                        ? IconButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                _formatTime(positionSeconds),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Container(width: 1, height: 28, color: colorScheme.outlineVariant),
            const SizedBox(width: 20),
            const TempoControls(),
            const SizedBox(width: 10),
            const SnapControl(),
            const SizedBox(width: 10),
            TimelineRulerModeControl(
              mode: rulerMode,
              onChanged: onRulerModeChanged,
            ),
            if (meterController != null) ...[
              const SizedBox(width: 14),
              MasterStereoMeter(controller: meterController!),
            ],
            if (isImporting)
              const Padding(
                padding: EdgeInsets.only(left: 20),
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
