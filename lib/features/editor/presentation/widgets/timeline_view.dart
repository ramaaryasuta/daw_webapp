import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'track_header.dart';

class TimelineTrackLane extends StatelessWidget {
  const TimelineTrackLane({
    super.key,
    required this.clipId,
    required this.fileName,
    required this.durationSeconds,
    required this.startTimeSeconds,
    required this.waveformPeaks,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.isSelected,
    required this.clipDragController,
    required this.onSeek,
    required this.onSelect,
    required this.onMoveCommitted,
  });

  final String clipId;
  final String fileName;

  final double durationSeconds;
  final double startTimeSeconds;

  final List<double> waveformPeaks;
  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final bool isSelected;
  final TimelineClipDragController clipDragController;
  final ValueChanged<double> onSeek;
  final VoidCallback onSelect;
  final ValueChanged<double> onMoveCommitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transform = gridMetrics.transform;

    void commitDrag(int pointer) {
      final result = clipDragController.end(pointer);
      if (result?.didMove ?? false) {
        onMoveCommitted(result!.startSeconds);
      }
    }

    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
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
              child: CustomPaint(
                painter: _GridPainter(
                  color: colorScheme.outlineVariant,
                  gridMetrics: gridMetrics,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TimelineClipDragState?>(
            valueListenable: clipDragController,
            builder: (context, dragState, child) {
              final isDragging = dragState?.clipId == clipId;
              final visualStartSeconds = isDragging
                  ? dragState!.previewStartSeconds
                  : startTimeSeconds;
              final clipWidth = transform.timeToContentX(durationSeconds);

              return Positioned(
                left: transform.timeToContentX(visualStartSeconds),
                top: 8,
                bottom: 8,
                width: math.max(clipWidth, 1),
                child: MouseRegion(
                  cursor: isDragging
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
                        clipId: clipId,
                        pointerGlobalX: event.position.dx,
                        clipStartSeconds: startTimeSeconds,
                        clipDurationSeconds: durationSeconds,
                        pixelsPerSecond: transform.scale.pixelsPerSecond,
                      );
                    },
                    onPointerMove: (event) {
                      if ((event.buttons & kPrimaryMouseButton) == 0) {
                        commitDrag(event.pointer);
                        return;
                      }

                      clipDragController.update(
                        pointer: event.pointer,
                        pointerGlobalX: event.position.dx,
                      );
                    },
                    onPointerUp: (event) => commitDrag(event.pointer),
                    onPointerCancel: (event) {
                      clipDragController.cancel(event.pointer);
                    },
                    child: _AudioClipSurface(
                      fileName: fileName,
                      durationSeconds: durationSeconds,
                      waveformPeaks: waveformPeaks,
                      isSelected: isSelected,
                      isDragging: isDragging,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: transform.timeToContentX(playheadSeconds) - 1,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(width: 2, color: colorScheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioClipSurface extends StatelessWidget {
  const _AudioClipSurface({
    required this.fileName,
    required this.durationSeconds,
    required this.waveformPeaks,
    required this.isSelected,
    required this.isDragging,
  });

  final String fileName;
  final double durationSeconds;
  final List<double> waveformPeaks;
  final bool isSelected;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isDragging
        ? colorScheme.tertiary
        : isSelected
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDragging
            ? colorScheme.primaryContainer.withValues(alpha: 0.92)
            : colorScheme.primaryContainer,
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
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.6,
                    ),
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
                  color: colorScheme.primaryContainer.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 5,
              child: Text(
                '${durationSeconds.toStringAsFixed(2)}s',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.peaks, required this.color});

  final List<double> peaks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;

    final maxWaveHeight = size.height * 0.44;

    // Tidak perlu menggambar lebih banyak
    // garis daripada pixel yang tersedia.
    final columnCount = math.min(math.max(size.width.floor(), 1), peaks.length);

    for (var column = 0; column < columnCount; column++) {
      final startIndex = (column * peaks.length / columnCount).floor();

      final endIndex = math.min(
        (((column + 1) * peaks.length / columnCount).ceil()),
        peaks.length,
      );

      var peak = 0.0;

      for (var i = startIndex; i < endIndex; i++) {
        if (peaks[i] > peak) {
          peak = peaks[i];
        }
      }

      final normalizedPeak = peak.clamp(0.0, 1.0);

      final amplitude = normalizedPeak * maxWaveHeight;

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
    return oldDelegate.peaks != peaks || oldDelegate.color != color;
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.color,
    required this.gridMetrics,
    required this.devicePixelRatio,
  });

  final Color color;
  final TimelineGridMetrics gridMetrics;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    final clipBounds = canvas.getLocalClipBounds();

    for (final tick in gridMetrics.ticksInContentRange(
      left: clipBounds.left,
      right: clipBounds.right,
      contentWidth: size.width,
    )) {
      final x = gridMetrics.alignStrokeCenter(
        tick.contentX,
        devicePixelRatio: devicePixelRatio,
      );
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tick.isMajor ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
