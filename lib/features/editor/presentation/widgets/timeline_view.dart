import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'track_header.dart';
import 'timeline_ruler.dart';

class TimelineTrackLane extends StatelessWidget {
  const TimelineTrackLane({
    super.key,
    required this.fileName,
    required this.durationSeconds,
    required this.startTimeSeconds,
    required this.waveformPeaks,
    required this.playheadSeconds,
    required this.onSeek,
  });

  final String fileName;

  final double durationSeconds;
  final double startTimeSeconds;

  final List<double> waveformPeaks;
  final double playheadSeconds;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final clipWidth = durationSeconds * TimelineRuler.secondWidth;

    final left = startTimeSeconds * TimelineRuler.secondWidth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        onSeek(details.localPosition.dx / TimelineRuler.secondWidth);
      },
      child: Container(
        height: trackHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Timeline vertical grid
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(color: colorScheme.outlineVariant),
              ),
            ),

            // Audio clip
            Positioned(
              left: left,
              top: 8,
              bottom: 8,
              width: math.max(clipWidth, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    border: Border.all(color: colorScheme.primary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      // Waveform
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

                      // Filename
                      Positioned(
                        left: 8,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.85,
                            ),
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

                      // Duration
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
              ),
            ),

            Positioned(
              left: playheadSeconds * TimelineRuler.secondWidth,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(width: 2, color: colorScheme.tertiary),
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
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    const width = TimelineRuler.secondWidth;

    for (double x = 0; x <= size.width; x += width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
