import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/timeline_scale.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.playheadSeconds,
    required this.scale,
    required this.onSeek,
  });

  static const double height = 32;

  final double playheadSeconds;
  final TimelineScale scale;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        onSeek(scale.pixelsToSeconds(details.localPosition.dx));
      },
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _TimelineRulerPainter(
            color: colorScheme.outline,
            playheadColor: colorScheme.tertiary,
            playheadSeconds: playheadSeconds,
            scale: scale,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  const _TimelineRulerPainter({
    required this.color,
    required this.playheadColor,
    required this.playheadSeconds,
    required this.scale,
  });

  final Color color;
  final Color playheadColor;
  final double playheadSeconds;
  final TimelineScale scale;

  @override
  void paint(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final clipBounds = canvas.getLocalClipBounds();
    final minorSpacing = scale.secondsToPixels(scale.minorTickIntervalSeconds);
    final firstIndex = math.max(
      0,
      (clipBounds.left / minorSpacing).floor() - 1,
    );
    final lastIndex = math.min(
      (size.width / minorSpacing).ceil(),
      (clipBounds.right / minorSpacing).ceil() + 1,
    );
    var previousLabelRight = double.negativeInfinity;

    for (var index = firstIndex; index <= lastIndex; index++) {
      final x = index * minorSpacing;
      final isMajor = index % scale.minorDivisions == 0;

      canvas.drawLine(
        Offset(x, isMajor ? 18 : 25),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );

      if (!isMajor) {
        continue;
      }

      final seconds = index * scale.minorTickIntervalSeconds;
      textPainter.text = TextSpan(
        text: scale.formatTickLabel(seconds),
        style: TextStyle(color: color, fontSize: 10),
      );
      textPainter.layout();

      final labelX = x + 4;
      if (labelX >= previousLabelRight + 6) {
        textPainter.paint(canvas, Offset(labelX, 2));
        previousLabelRight = labelX + textPainter.width;
      }
    }

    final playheadX = scale.secondsToPixels(playheadSeconds);
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

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.playheadSeconds != playheadSeconds ||
        oldDelegate.scale.pixelsPerSecond != scale.pixelsPerSecond;
  }
}
