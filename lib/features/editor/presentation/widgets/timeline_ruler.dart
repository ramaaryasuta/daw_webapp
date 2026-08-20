import 'package:flutter/material.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.playheadSeconds,
    required this.onSeek,
  });

  static const double height = 32;
  static const double secondWidth = 100;

  final double playheadSeconds;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        onSeek(details.localPosition.dx / secondWidth);
      },
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _TimelineRulerPainter(
            color: colorScheme.outline,
            playheadColor: colorScheme.tertiary,
            playheadSeconds: playheadSeconds,
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
  });

  final Color color;
  final Color playheadColor;
  final double playheadSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const secondWidth = TimelineRuler.secondWidth;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    var second = 0;

    for (double x = 0; x <= size.width; x += secondWidth) {
      canvas.drawLine(Offset(x, 18), Offset(x, size.height), paint);

      textPainter.text = TextSpan(
        text: '${second}s',
        style: TextStyle(color: color, fontSize: 10),
      );

      textPainter.layout();

      textPainter.paint(canvas, Offset(x + 4, 2));

      second++;
    }

    final playheadX = playheadSeconds * secondWidth;
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
        oldDelegate.playheadSeconds != playheadSeconds;
  }
}
