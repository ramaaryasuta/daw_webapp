import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/musical_timing.dart';
import '../../domain/timeline_scale.dart';
import '../models/timeline_ruler_mode.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.onSeek,
    this.mode = TimelineRulerMode.barsBeats,
    this.bpm = 120,
    this.beatsPerBar = defaultBeatsPerBar,
  });

  static const double height = 32;

  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final ValueChanged<double> onSeek;
  final TimelineRulerMode mode;
  final double bpm;
  final int beatsPerBar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        onSeek(gridMetrics.transform.contentXToTime(details.localPosition.dx));
      },
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: TimelineRulerPainter(
            color: colorScheme.outline,
            playheadColor: colorScheme.tertiary,
            playheadSeconds: playheadSeconds,
            gridMetrics: gridMetrics,
            mode: mode,
            bpm: bpm,
            beatsPerBar: beatsPerBar,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class TimelineRulerPainter extends CustomPainter {
  const TimelineRulerPainter({
    required this.color,
    required this.playheadColor,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.mode,
    required this.bpm,
    required this.beatsPerBar,
    required this.devicePixelRatio,
  });

  static const double _minimumTickSpacing = 8;
  static const double _minimumLabelSpacing = 42;
  static const double _labelGap = 6;

  final Color color;
  final Color playheadColor;
  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final TimelineRulerMode mode;
  final double bpm;
  final int beatsPerBar;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case TimelineRulerMode.barsBeats:
        _paintMusicalTicks(canvas, size);
        break;
      case TimelineRulerMode.time:
        _paintTimeTicks(canvas, size);
        break;
    }

    _paintPlayhead(canvas, size);
  }

  void _paintTimeTicks(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final clipBounds = canvas.getLocalClipBounds();
    var previousLabelRight = double.negativeInfinity;

    for (final tick in gridMetrics.ticksInContentRange(
      left: clipBounds.left,
      right: clipBounds.right,
      contentWidth: size.width,
    )) {
      final x = _alignedX(tick.contentX);

      canvas.drawLine(
        Offset(x, tick.isMajor ? 18 : 25),
        Offset(x, size.height),
        tick.isMajor ? majorPaint : minorPaint,
      );

      if (!tick.isMajor) {
        continue;
      }

      previousLabelRight = _paintLabelIfClear(
        canvas: canvas,
        textPainter: textPainter,
        label: gridMetrics.scale.formatTickLabel(tick.timeSeconds),
        x: x,
        previousLabelRight: previousLabelRight,
      );
    }
  }

  void _paintMusicalTicks(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final timing = MusicalTiming(bpm: bpm, beatsPerBar: beatsPerBar);
    final transform = gridMetrics.transform;
    final clipBounds = canvas.getLocalClipBounds();
    final visibleStartSeconds = math.max(
      0.0,
      transform.contentXToTime(clipBounds.left),
    );
    final visibleEndSeconds = math.min(
      transform.contentXToTime(size.width),
      transform.contentXToTime(clipBounds.right),
    );

    if (visibleEndSeconds < visibleStartSeconds) {
      return;
    }

    final beatSeconds = timing.beatDurationSeconds;
    final beatSpacing = transform.timeToContentX(beatSeconds);
    final barSpacing = transform.timeToContentX(timing.barDurationSeconds);
    final subdivisionCount = _visibleSubdivisionsPerBeat(beatSpacing);

    if (subdivisionCount > 1) {
      _paintSubdivisions(
        canvas: canvas,
        size: size,
        visibleStartSeconds: visibleStartSeconds,
        visibleEndSeconds: visibleEndSeconds,
        beatSeconds: beatSeconds,
        subdivisionsPerBeat: subdivisionCount,
      );
    }

    if (beatSpacing >= _minimumTickSpacing) {
      _paintBeatTicks(
        canvas: canvas,
        size: size,
        timing: timing,
        visibleStartSeconds: visibleStartSeconds,
        visibleEndSeconds: visibleEndSeconds,
      );
    }

    _paintBarTicks(
      canvas: canvas,
      size: size,
      timing: timing,
      visibleStartSeconds: visibleStartSeconds,
      visibleEndSeconds: visibleEndSeconds,
      barSpacing: barSpacing,
    );

    _paintMusicalLabels(
      canvas: canvas,
      timing: timing,
      visibleStartSeconds: visibleStartSeconds,
      visibleEndSeconds: visibleEndSeconds,
      beatSpacing: beatSpacing,
      barSpacing: barSpacing,
    );
  }

  int _visibleSubdivisionsPerBeat(double beatSpacing) {
    for (final divisions in const [8, 4, 2]) {
      if (beatSpacing / divisions >= _minimumTickSpacing) {
        return divisions;
      }
    }
    return 1;
  }

  void _paintSubdivisions({
    required Canvas canvas,
    required Size size,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double beatSeconds,
    required int subdivisionsPerBeat,
  }) {
    final intervalSeconds = beatSeconds / subdivisionsPerBeat;
    final firstIndex = math.max(
      0,
      (visibleStartSeconds / intervalSeconds).floor() - 1,
    );
    final lastIndex = (visibleEndSeconds / intervalSeconds).ceil() + 1;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (var index = firstIndex; index <= lastIndex; index++) {
      if (index % subdivisionsPerBeat == 0) {
        continue;
      }
      final timeSeconds = index * intervalSeconds;
      final x = _alignedX(gridMetrics.transform.timeToContentX(timeSeconds));
      canvas.drawLine(Offset(x, 27), Offset(x, size.height), paint);
    }
  }

  void _paintBeatTicks({
    required Canvas canvas,
    required Size size,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
  }) {
    final beatSeconds = timing.beatDurationSeconds;
    final firstBeatIndex = math.max(
      0,
      (visibleStartSeconds / beatSeconds).floor() - 1,
    );
    final lastBeatIndex = (visibleEndSeconds / beatSeconds).ceil() + 1;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.58)
      ..strokeWidth = 1;

    for (
      var beatIndex = firstBeatIndex;
      beatIndex <= lastBeatIndex;
      beatIndex++
    ) {
      if (timing.isDownbeat(beatIndex)) {
        continue;
      }
      final x = _alignedX(
        gridMetrics.transform.timeToContentX(timing.beatTimeSeconds(beatIndex)),
      );
      canvas.drawLine(Offset(x, 21), Offset(x, size.height), paint);
    }
  }

  void _paintBarTicks({
    required Canvas canvas,
    required Size size,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double barSpacing,
  }) {
    final barSeconds = timing.barDurationSeconds;
    final stride = math.max(1, (_minimumTickSpacing / barSpacing).ceil());
    final firstVisibleBar = math.max(
      0,
      (visibleStartSeconds / barSeconds).floor() - 1,
    );
    final firstBar = firstVisibleBar - firstVisibleBar % stride;
    final lastBar = (visibleEndSeconds / barSeconds).ceil() + stride;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var barIndex = firstBar; barIndex <= lastBar; barIndex += stride) {
      final timeSeconds = barIndex * barSeconds;
      final x = _alignedX(gridMetrics.transform.timeToContentX(timeSeconds));
      canvas.drawLine(Offset(x, 15), Offset(x, size.height), paint);
    }
  }

  void _paintMusicalLabels({
    required Canvas canvas,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double beatSpacing,
    required double barSpacing,
  }) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    var previousLabelRight = double.negativeInfinity;

    if (beatSpacing >= _minimumLabelSpacing) {
      final beatSeconds = timing.beatDurationSeconds;
      final firstBeatIndex = math.max(
        0,
        (visibleStartSeconds / beatSeconds).floor() - 1,
      );
      final lastBeatIndex = (visibleEndSeconds / beatSeconds).ceil() + 1;

      for (
        var beatIndex = firstBeatIndex;
        beatIndex <= lastBeatIndex;
        beatIndex++
      ) {
        final x = _alignedX(
          gridMetrics.transform.timeToContentX(
            timing.beatTimeSeconds(beatIndex),
          ),
        );
        previousLabelRight = _paintLabelIfClear(
          canvas: canvas,
          textPainter: textPainter,
          label: timing.positionAtBeatIndex(beatIndex).label,
          x: x,
          previousLabelRight: previousLabelRight,
        );
      }
      return;
    }

    final barSeconds = timing.barDurationSeconds;
    final labelStride = math.max(1, (_minimumLabelSpacing / barSpacing).ceil());
    final firstVisibleBar = math.max(
      0,
      (visibleStartSeconds / barSeconds).floor() - 1,
    );
    final firstBar = firstVisibleBar - firstVisibleBar % labelStride;
    final lastBar = (visibleEndSeconds / barSeconds).ceil() + labelStride;

    for (
      var barIndex = firstBar;
      barIndex <= lastBar;
      barIndex += labelStride
    ) {
      final x = _alignedX(
        gridMetrics.transform.timeToContentX(barIndex * barSeconds),
      );
      previousLabelRight = _paintLabelIfClear(
        canvas: canvas,
        textPainter: textPainter,
        label: '${barIndex + 1}',
        x: x,
        previousLabelRight: previousLabelRight,
      );
    }
  }

  double _paintLabelIfClear({
    required Canvas canvas,
    required TextPainter textPainter,
    required String label,
    required double x,
    required double previousLabelRight,
  }) {
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(color: color, fontSize: 10),
    );
    textPainter.layout();

    final labelX = x + 4;
    if (labelX < previousLabelRight + _labelGap) {
      return previousLabelRight;
    }

    textPainter.paint(canvas, Offset(labelX, 2));
    return labelX + textPainter.width;
  }

  void _paintPlayhead(Canvas canvas, Size size) {
    final playheadX = gridMetrics.alignStrokeCenter(
      gridMetrics.transform.timeToContentX(playheadSeconds),
      devicePixelRatio: devicePixelRatio,
      strokeWidth: 2,
    );
    final playheadPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    final marker = Path()
      ..moveTo(playheadX - 5, 0)
      ..lineTo(playheadX + 5, 0)
      ..lineTo(playheadX, 7)
      ..close();

    canvas.drawPath(marker, playheadPaint);
  }

  double _alignedX(double contentX) {
    return gridMetrics.alignStrokeCenter(
      contentX,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  bool shouldRepaint(covariant TimelineRulerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.playheadSeconds != playheadSeconds ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.gridMetrics.transform.horizontalScrollOffset !=
            gridMetrics.transform.horizontalScrollOffset ||
        oldDelegate.mode != mode ||
        oldDelegate.bpm != bpm ||
        oldDelegate.beatsPerBar != beatsPerBar ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
