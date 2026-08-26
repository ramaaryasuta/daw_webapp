import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/audio_clip.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'track_header.dart';

class TimelineTrackLane extends StatelessWidget {
  const TimelineTrackLane({
    super.key,
    required this.clips,
    this.trackColorValue = 0xFF8468C8,
    required this.gridMetrics,
    required this.selectedClipId,
    required this.clipDragController,
    this.bpm = 120,
    this.snapSettings = const SnapSettings(enabled: false),
    required this.onSeek,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
  });

  final List<AudioClip> clips;
  final int trackColorValue;
  final TimelineGridMetrics gridMetrics;
  final String? selectedClipId;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final SnapSettings snapSettings;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onSelect;
  final void Function(String clipId, double startSeconds) onMoveCommitted;
  final void Function(String clipId, TimelineClipDragResult result)
  onTrimCommitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transform = gridMetrics.transform;

    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                onSeek(transform.contentXToTime(details.localPosition.dx));
              },
              child: const SizedBox.expand(),
            ),
          ),
          for (final clip in clips)
            _TimelineAudioClip(
              key: ValueKey(clip.id),
              clip: clip,
              trackColor: Color(trackColorValue),
              transform: transform,
              isSelected: selectedClipId == clip.id,
              clipDragController: clipDragController,
              bpm: bpm,
              snapSettings: snapSettings,
              onSelect: () => onSelect(clip.id),
              onMoveCommitted: (start) => onMoveCommitted(clip.id, start),
              onTrimCommitted: (result) => onTrimCommitted(clip.id, result),
            ),
        ],
      ),
    );
  }
}

class _TimelineAudioClip extends StatelessWidget {
  const _TimelineAudioClip({
    super.key,
    required this.clip,
    required this.trackColor,
    required this.transform,
    required this.isSelected,
    required this.clipDragController,
    required this.bpm,
    required this.snapSettings,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
  });

  final AudioClip clip;
  final Color trackColor;
  final TimelineTransform transform;
  final bool isSelected;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final SnapSettings snapSettings;
  final VoidCallback onSelect;
  final ValueChanged<double> onMoveCommitted;
  final ValueChanged<TimelineClipDragResult> onTrimCommitted;

  @override
  Widget build(BuildContext context) {
    void commitDrag(int pointer) {
      final result = clipDragController.end(pointer);
      if (!(result?.didChange ?? false)) {
        return;
      }

      switch (result!.mode) {
        case TimelineClipDragMode.move:
          onMoveCommitted(result.startSeconds);
          break;
        case TimelineClipDragMode.trimStart:
        case TimelineClipDragMode.trimEnd:
          onTrimCommitted(result);
          break;
      }
    }

    void updateDrag(PointerMoveEvent event) {
      if ((event.buttons & kPrimaryMouseButton) == 0) {
        commitDrag(event.pointer);
        return;
      }
      clipDragController.update(
        pointer: event.pointer,
        pointerGlobalX: event.position.dx,
        bypassSnap: HardwareKeyboard.instance.isAltPressed,
      );
    }

    return ValueListenableBuilder<TimelineClipDragState?>(
      valueListenable: clipDragController,
      builder: (context, dragState, child) {
        final isDragging = dragState?.clipId == clip.id;
        final visualStartSeconds = isDragging
            ? dragState!.previewStartSeconds
            : clip.timelineStartSeconds;
        final visualSourceStartSeconds = isDragging
            ? dragState!.previewSourceStartSeconds
            : clip.sourceStartSeconds;
        final visualDurationSeconds = isDragging
            ? dragState!.clipDurationSeconds
            : clip.clipDurationSeconds;
        final renderedClipWidth = math.max(
          transform.timeToContentX(visualDurationSeconds),
          1.0,
        );
        final trimHitWidth = math.min(12.0, renderedClipWidth / 2);

        return Positioned(
          left: transform.timeToContentX(visualStartSeconds),
          top: 8,
          bottom: 8,
          width: renderedClipWidth,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor:
                      isDragging && dragState!.mode == TimelineClipDragMode.move
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if ((event.buttons & kPrimaryMouseButton) == 0) {
                        return;
                      }
                      onSelect();
                      clipDragController.begin(
                        pointer: event.pointer,
                        clipId: clip.id,
                        pointerGlobalX: event.position.dx,
                        clipStartSeconds: clip.timelineStartSeconds,
                        sourceStartSeconds: clip.sourceStartSeconds,
                        clipDurationSeconds: clip.clipDurationSeconds,
                        sourceAudioDurationSeconds:
                            clip.sourceAudioDurationSeconds,
                        pixelsPerSecond: transform.scale.pixelsPerSecond,
                        bpm: bpm,
                        snapSettings: snapSettings,
                      );
                    },
                    onPointerMove: updateDrag,
                    onPointerUp: (event) => commitDrag(event.pointer),
                    onPointerCancel: (event) {
                      clipDragController.cancel(event.pointer);
                    },
                    child: _AudioClipSurface(
                      fileName: clip.audio.name,
                      clipDurationSeconds: visualDurationSeconds,
                      sourceStartSeconds: visualSourceStartSeconds,
                      sourceAudioDurationSeconds:
                          clip.sourceAudioDurationSeconds,
                      waveformPeaks: clip.audio.waveformPeaks,
                      trackColor: trackColor,
                      isSelected: isSelected,
                      isDragging: isDragging,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: trimHitWidth,
                child: _TrimHandle(
                  side: TimelineClipDragMode.trimStart,
                  isSelected: isSelected,
                  isActive:
                      isDragging &&
                      dragState!.mode == TimelineClipDragMode.trimStart,
                  onPointerDown: (event) => _beginTrim(
                    event: event,
                    side: TimelineClipDragMode.trimStart,
                  ),
                  onPointerMove: updateDrag,
                  onPointerUp: (event) => commitDrag(event.pointer),
                  onPointerCancel: (event) {
                    clipDragController.cancel(event.pointer);
                  },
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: trimHitWidth,
                child: _TrimHandle(
                  side: TimelineClipDragMode.trimEnd,
                  isSelected: isSelected,
                  isActive:
                      isDragging &&
                      dragState!.mode == TimelineClipDragMode.trimEnd,
                  onPointerDown: (event) => _beginTrim(
                    event: event,
                    side: TimelineClipDragMode.trimEnd,
                  ),
                  onPointerMove: updateDrag,
                  onPointerUp: (event) => commitDrag(event.pointer),
                  onPointerCancel: (event) {
                    clipDragController.cancel(event.pointer);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _beginTrim({
    required PointerDownEvent event,
    required TimelineClipDragMode side,
  }) {
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    onSelect();
    clipDragController.beginTrim(
      pointer: event.pointer,
      clipId: clip.id,
      mode: side,
      pointerGlobalX: event.position.dx,
      clipStartSeconds: clip.timelineStartSeconds,
      sourceStartSeconds: clip.sourceStartSeconds,
      clipDurationSeconds: clip.clipDurationSeconds,
      sourceAudioDurationSeconds: clip.sourceAudioDurationSeconds,
      pixelsPerSecond: transform.scale.pixelsPerSecond,
      bpm: bpm,
      snapSettings: snapSettings,
    );
  }
}

class _TrimHandle extends StatefulWidget {
  const _TrimHandle({
    required this.side,
    required this.isSelected,
    required this.isActive,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final TimelineClipDragMode side;
  final bool isSelected;
  final bool isActive;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showAffordance = _isHovered || widget.isSelected || widget.isActive;
    final alignment = widget.side == TimelineClipDragMode.trimStart
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.onPointerDown,
        onPointerMove: widget.onPointerMove,
        onPointerUp: widget.onPointerUp,
        onPointerCancel: widget.onPointerCancel,
        child: Align(
          alignment: alignment,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: showAffordance
                  ? widget.isActive
                        ? colorScheme.tertiary
                        : colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioClipSurface extends StatelessWidget {
  const _AudioClipSurface({
    required this.fileName,
    required this.clipDurationSeconds,
    required this.sourceStartSeconds,
    required this.sourceAudioDurationSeconds,
    required this.waveformPeaks,
    required this.trackColor,
    required this.isSelected,
    required this.isDragging,
  });

  final String fileName;
  final double clipDurationSeconds;
  final double sourceStartSeconds;
  final double sourceAudioDurationSeconds;
  final List<double> waveformPeaks;
  final Color trackColor;
  final bool isSelected;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = Color.alphaBlend(
      trackColor.withValues(alpha: isDragging ? 0.34 : 0.24),
      colorScheme.surfaceContainerHigh,
    );
    final waveformColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.68);
    final identityBorderColor = trackColor.computeLuminance() < 0.035
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.38), trackColor)
        : trackColor.withValues(alpha: 0.9);
    final borderColor = isDragging
        ? colorScheme.tertiary
        : isSelected
        ? colorScheme.onSurface
        : identityBorderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: isDragging || isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : isSelected
            ? [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(alpha: 0.14),
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    peaks: waveformPeaks,
                    sourceStartSeconds: sourceStartSeconds,
                    clipDurationSeconds: clipDurationSeconds,
                    sourceAudioDurationSeconds: sourceAudioDurationSeconds,
                    color: waveformColor,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    colorScheme.surface.withValues(alpha: 0.72),
                    backgroundColor,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 5,
              child: Text(
                '${clipDurationSeconds.toStringAsFixed(2)}s',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.peaks,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.sourceAudioDurationSeconds,
    required this.color,
  });

  final List<double> peaks;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double sourceAudioDurationSeconds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty ||
        sourceAudioDurationSeconds <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final visibleStartIndex =
        (sourceStartSeconds / sourceAudioDurationSeconds * peaks.length)
            .floor()
            .clamp(0, peaks.length - 1);
    final visibleEndIndex =
        ((sourceStartSeconds + clipDurationSeconds) /
                sourceAudioDurationSeconds *
                peaks.length)
            .ceil()
            .clamp(visibleStartIndex + 1, peaks.length);
    final visiblePeakCount = visibleEndIndex - visibleStartIndex;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final maxWaveHeight = size.height * 0.44;
    final columnCount = math.min(
      math.max(size.width.floor(), 1),
      visiblePeakCount,
    );

    for (var column = 0; column < columnCount; column++) {
      final startIndex =
          visibleStartIndex + (column * visiblePeakCount / columnCount).floor();
      final endIndex = math.min(
        visibleStartIndex +
            (((column + 1) * visiblePeakCount / columnCount).ceil()),
        visibleEndIndex,
      );
      var peak = 0.0;

      for (var i = startIndex; i < endIndex; i++) {
        if (peaks[i] > peak) {
          peak = peaks[i];
        }
      }

      final amplitude = peak.clamp(0.0, 1.0) * maxWaveHeight;
      final x = columnCount == 1
          ? size.width / 2
          : column * size.width / (columnCount - 1);
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.sourceStartSeconds != sourceStartSeconds ||
        oldDelegate.clipDurationSeconds != clipDurationSeconds ||
        oldDelegate.sourceAudioDurationSeconds != sourceAudioDurationSeconds ||
        oldDelegate.color != color;
  }
}
