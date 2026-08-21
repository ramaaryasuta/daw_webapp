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

  static const double minimumLineSpacing = 8;

  final Color color;
  final TimelineGridMetrics gridMetrics;
  final double bpm;
  final SnapSettings settings;
  final double devicePixelRatio;
  final int beatsPerBar;

  @override
  void paint(Canvas canvas, Size size) {
    if (!settings.enabled || size.width <= 0 || size.height <= 0) {
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
    final barStride = math.max(1, (minimumLineSpacing / barSpacing).ceil());
    _paintInterval(
      canvas: canvas,
      size: size,
      leftSeconds: leftSeconds,
      rightSeconds: rightSeconds,
      intervalSeconds: barSeconds * barStride,
      paint: Paint()
        ..color = color.withValues(alpha: 0.48)
        ..strokeWidth = 1,
    );

    if (settings.subdivision == SnapSubdivision.bar) {
      return;
    }

    final beatSpacing = gridMetrics.transform.timeToContentX(beatSeconds);
    if (beatSpacing >= minimumLineSpacing) {
      _paintInterval(
        canvas: canvas,
        size: size,
        leftSeconds: leftSeconds,
        rightSeconds: rightSeconds,
        intervalSeconds: beatSeconds,
        skipEvery: beatsPerBar,
        paint: Paint()
          ..color = color.withValues(alpha: 0.31)
          ..strokeWidth = 1,
      );
    }

    if (subdivisionSeconds >= beatSeconds) {
      return;
    }

    final subdivisionSpacing = gridMetrics.transform.timeToContentX(
      subdivisionSeconds,
    );
    if (subdivisionSpacing < minimumLineSpacing) {
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
        ..color = color.withValues(alpha: 0.16)
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
