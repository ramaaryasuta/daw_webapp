import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/musical_timing.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../../domain/timeline_snapper.dart';

class MusicalGridPainter extends CustomPainter {
  const MusicalGridPainter({
    required this.color,
    required this.gridMetrics,
    required this.bpm,
    required this.settings,
    required this.devicePixelRatio,
    this.beatsPerBar = defaultBeatsPerBar,
  });

  /// Bars remain readable rather than collapsing into a dense barcode.
  static const double minimumBarLineSpacing = 36;

  /// Beat lines disappear before they can collapse into a dense barcode.
  static const double minimumBeatLineSpacing = 12;

  /// Snap remains precise below this threshold; only its visual subdivision
  /// line is omitted.
  static const double minimumSubdivisionLineSpacing = 18;

  final Color color;
  final TimelineGridMetrics gridMetrics;
  final double bpm;
  final SnapSettings settings;
  final double devicePixelRatio;
  final int beatsPerBar;

  double get beatLineSpacing {
    return gridMetrics.transform.timeToContentX(
      MusicalTiming(bpm: bpm, beatsPerBar: beatsPerBar).beatDurationSeconds,
    );
  }

  double get subdivisionLineSpacing {
    return gridMetrics.transform.timeToContentX(
      TimelineSnapper.intervalSeconds(
        bpm: bpm,
        subdivision: settings.subdivision,
        beatsPerBar: beatsPerBar,
      ),
    );
  }

  bool get paintsBeatLines => beatLineSpacing >= minimumBeatLineSpacing;

  bool get paintsSubdivisionLines {
    return settings.enabled &&
        settings.subdivision != SnapSubdivision.bar &&
        subdivisionLineSpacing < beatLineSpacing &&
        subdivisionLineSpacing >= minimumSubdivisionLineSpacing;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final timing = MusicalTiming(bpm: bpm, beatsPerBar: beatsPerBar);
    final beatSeconds = timing.beatDurationSeconds;
    final barSeconds = timing.barDurationSeconds;
    final subdivisionSeconds = TimelineSnapper.intervalSeconds(
      bpm: bpm,
      subdivision: settings.subdivision,
      beatsPerBar: beatsPerBar,
    );
    final clipBounds = canvas.getLocalClipBounds();
    final leftSeconds = math.max(
      0.0,
      gridMetrics.transform.contentXToTime(clipBounds.left),
    );
    final rightSeconds = math.min(
      gridMetrics.transform.contentXToTime(size.width),
      gridMetrics.transform.contentXToTime(clipBounds.right),
    );

    if (rightSeconds < leftSeconds) {
      return;
    }

    final barSpacing = gridMetrics.transform.timeToContentX(barSeconds);
    final barStride = math.max(1, (minimumBarLineSpacing / barSpacing).ceil());
    _paintInterval(
      canvas: canvas,
      size: size,
      leftSeconds: leftSeconds,
      rightSeconds: rightSeconds,
      intervalSeconds: barSeconds * barStride,
      paint: Paint()
        ..color = color.withValues(alpha: 0.68)
        ..strokeWidth = 1,
    );

    if (paintsBeatLines) {
      _paintInterval(
        canvas: canvas,
        size: size,
        leftSeconds: leftSeconds,
        rightSeconds: rightSeconds,
        intervalSeconds: beatSeconds,
        skipEvery: beatsPerBar,
        paint: Paint()
          ..color = color.withValues(alpha: 0.34)
          ..strokeWidth = 1,
      );
    }

    if (!paintsSubdivisionLines) {
      return;
    }

    final subdivisionsPerBeat = (beatSeconds / subdivisionSeconds).round();
    _paintInterval(
      canvas: canvas,
      size: size,
      leftSeconds: leftSeconds,
      rightSeconds: rightSeconds,
      intervalSeconds: subdivisionSeconds,
      skipEvery: subdivisionsPerBeat,
      paint: Paint()
        ..color = color.withValues(alpha: 0.13)
        ..strokeWidth = 1,
    );
  }

  void _paintInterval({
    required Canvas canvas,
    required Size size,
    required double leftSeconds,
    required double rightSeconds,
    required double intervalSeconds,
    required Paint paint,
    int? skipEvery,
  }) {
    final firstIndex = math.max(0, (leftSeconds / intervalSeconds).floor() - 1);
    final lastIndex = (rightSeconds / intervalSeconds).ceil() + 1;

    for (var index = firstIndex; index <= lastIndex; index++) {
      if (skipEvery != null && index % skipEvery == 0) {
        continue;
      }
      final timeSeconds = index * intervalSeconds;
      final contentX = gridMetrics.transform.timeToContentX(timeSeconds);
      final x = gridMetrics.alignStrokeCenter(
        contentX,
        devicePixelRatio: devicePixelRatio,
      );
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant MusicalGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.bpm != bpm ||
        oldDelegate.settings.enabled != settings.enabled ||
        oldDelegate.settings.subdivision != settings.subdivision ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.beatsPerBar != beatsPerBar;
  }
}
