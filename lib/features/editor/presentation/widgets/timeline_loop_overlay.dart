import 'package:flutter/material.dart';

import '../../domain/loop_region.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../models/timeline_ruler_mode.dart';
import 'musical_grid_painter.dart';
import 'track_header.dart';
import 'track_lane_background_painter.dart';

/// Shared, non-interactive loop and playhead visualization for the complete
/// visible track viewport.
class TimelineLoopOverlay extends StatelessWidget {
  const TimelineLoopOverlay({
    super.key,
    required this.child,
    required this.gridMetrics,
    required this.playheadSeconds,
    required this.loopRegion,
    required this.isLoopEnabled,
    required this.bpm,
    required this.snapSettings,
    required this.rulerMode,
    required this.verticalScrollController,
  });

  final Widget child;
  final TimelineGridMetrics gridMetrics;
  final double playheadSeconds;
  final LoopRegion? loopRegion;
  final bool isLoopEnabled;
  final double bpm;
  final SnapSettings snapSettings;
  final TimelineRulerMode rulerMode;
  final ScrollController verticalScrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final baseLaneColor = colorScheme.surfaceContainerLowest;
    final alternateLaneColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.018),
      baseLaneColor,
    );

    return ClipRect(
      key: const ValueKey('timeline-track-viewport-clip'),
      child: AnimatedBuilder(
        animation: verticalScrollController,
        child: child,
        builder: (context, child) => ColoredBox(
          color: baseLaneColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  painter: TrackLaneBackgroundPainter(
                    baseColor: baseLaneColor,
                    alternateColor: alternateLaneColor,
                    separatorColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.72,
                    ),
                    rowHeight: trackHeight,
                    scrollOffset: verticalScrollController.hasClients
                        ? verticalScrollController.offset
                        : 0,
                    devicePixelRatio: devicePixelRatio,
                  ),
                ),
              ),
              if (rulerMode == TimelineRulerMode.time)
                IgnorePointer(
                  child: CustomPaint(
                    painter: TimelineGridPainter(
                      color: colorScheme.outlineVariant,
                      gridMetrics: gridMetrics,
                      devicePixelRatio: devicePixelRatio,
                    ),
                  ),
                )
              else
                IgnorePointer(
                  child: CustomPaint(
                    painter: MusicalGridPainter(
                      color: colorScheme.outlineVariant,
                      gridMetrics: gridMetrics,
                      bpm: bpm,
                      settings: snapSettings,
                      devicePixelRatio: devicePixelRatio,
                    ),
                  ),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: TimelineLoopFillPainter(
                    color: colorScheme.primary,
                    gridMetrics: gridMetrics,
                    loopRegion: loopRegion,
                    isLoopEnabled: isLoopEnabled,
                  ),
                ),
              ),
              child!,
              IgnorePointer(
                child: CustomPaint(
                  painter: TimelineLoopLinesPainter(
                    loopColor: colorScheme.primary,
                    playheadColor: colorScheme.tertiary,
                    gridMetrics: gridMetrics,
                    loopRegion: loopRegion,
                    isLoopEnabled: isLoopEnabled,
                    playheadSeconds: playheadSeconds,
                    devicePixelRatio: devicePixelRatio,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimelineGridPainter extends CustomPainter {
  const TimelineGridPainter({
    required this.color,
    required this.gridMetrics,
    required this.devicePixelRatio,
  });

  final Color color;
  final TimelineGridMetrics gridMetrics;
  final double devicePixelRatio;

  static const double minimumMinorLineSpacing = 16;

  bool get paintsMinorLines {
    return gridMetrics.minorTickSpacing >= minimumMinorLineSpacing;
  }

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
      if (!tick.isMajor && !paintsMinorLines) {
        continue;
      }
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tick.isMajor ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TimelineGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

class TimelineLoopFillPainter extends CustomPainter {
  const TimelineLoopFillPainter({
    required this.color,
    required this.gridMetrics,
    required this.loopRegion,
    required this.isLoopEnabled,
  });

  final Color color;
  final TimelineGridMetrics gridMetrics;
  final LoopRegion? loopRegion;
  final bool isLoopEnabled;

  Color get fillColor => color.withValues(alpha: isLoopEnabled ? 0.09 : 0.045);

  Rect? loopRectForSize(Size size) {
    final region = loopRegion;
    if (region == null || size.isEmpty) {
      return null;
    }
    final transform = gridMetrics.transform;
    return Rect.fromLTRB(
      transform.timeToContentX(region.startSeconds),
      0,
      transform.timeToContentX(region.endSeconds),
      size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final loopRect = loopRectForSize(size);
    if (loopRect == null) {
      return;
    }
    final paint = Paint()..color = fillColor;

    canvas.drawRect(loopRect, paint);
  }

  @override
  bool shouldRepaint(covariant TimelineLoopFillPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.isLoopEnabled != isLoopEnabled ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.gridMetrics.transform.horizontalScrollOffset !=
            gridMetrics.transform.horizontalScrollOffset;
  }
}

class TimelineLoopLinesPainter extends CustomPainter {
  const TimelineLoopLinesPainter({
    required this.loopColor,
    required this.playheadColor,
    required this.gridMetrics,
    required this.loopRegion,
    required this.isLoopEnabled,
    required this.playheadSeconds,
    required this.devicePixelRatio,
  });

  final Color loopColor;
  final Color playheadColor;
  final TimelineGridMetrics gridMetrics;
  final LoopRegion? loopRegion;
  final bool isLoopEnabled;
  final double playheadSeconds;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final transform = gridMetrics.transform;
    final region = loopRegion;

    if (region != null) {
      final loopPaint = Paint()
        ..color = loopColor.withValues(alpha: isLoopEnabled ? 0.78 : 0.42)
        ..strokeWidth = 1.25;
      final startX = gridMetrics.alignStrokeCenter(
        transform.timeToContentX(region.startSeconds),
        devicePixelRatio: devicePixelRatio,
        strokeWidth: loopPaint.strokeWidth,
      );
      final endX = gridMetrics.alignStrokeCenter(
        transform.timeToContentX(region.endSeconds),
        devicePixelRatio: devicePixelRatio,
        strokeWidth: loopPaint.strokeWidth,
      );
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX, size.height),
        loopPaint,
      );
      canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), loopPaint);
    }

    final playheadPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2;
    final playheadX = gridMetrics.alignStrokeCenter(
      transform.timeToContentX(playheadSeconds),
      devicePixelRatio: devicePixelRatio,
      strokeWidth: playheadPaint.strokeWidth,
    );
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TimelineLoopLinesPainter oldDelegate) {
    return oldDelegate.loopColor != loopColor ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.isLoopEnabled != isLoopEnabled ||
        oldDelegate.playheadSeconds != playheadSeconds ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.gridMetrics.transform.horizontalScrollOffset !=
            gridMetrics.transform.horizontalScrollOffset ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
