import 'package:flutter/material.dart';

import '../../domain/timeline_scale.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.onSeek,
  });

  static const double height = 32;

  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final ValueChanged<double> onSeek;

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
          painter: _TimelineRulerPainter(
            color: colorScheme.outline,
            playheadColor: colorScheme.tertiary,
            playheadSeconds: playheadSeconds,
            gridMetrics: gridMetrics,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
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
    required this.gridMetrics,
    required this.devicePixelRatio,
  });

  final Color color;
  final Color playheadColor;
  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final double devicePixelRatio;

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
    var previousLabelRight = double.negativeInfinity;

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
        Offset(x, tick.isMajor ? 18 : 25),
        Offset(x, size.height),
        tick.isMajor ? majorPaint : minorPaint,
      );

      if (!tick.isMajor) {
        continue;
      }

      textPainter.text = TextSpan(
        text: gridMetrics.scale.formatTickLabel(tick.timeSeconds),
        style: TextStyle(color: color, fontSize: 10),
      );
      textPainter.layout();

      final labelX = x + 4;
      if (labelX >= previousLabelRight + 6) {
        textPainter.paint(canvas, Offset(labelX, 2));
        previousLabelRight = labelX + textPainter.width;
      }
    }

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

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.playheadSeconds != playheadSeconds ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
