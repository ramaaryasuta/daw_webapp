import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/audio_meter_controller.dart';

class TrackStereoMeter extends StatelessWidget {
  const TrackStereoMeter({
    super.key,
    required this.controller,
    required this.trackId,
  });

  final AudioMeterController controller;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: 'Stereo level meter',
        child: SizedBox(
          key: ValueKey('track-level-meter-$trackId'),
          width: 20,
          height: 68,
          child: CustomPaint(
            painter: _TrackMeterPainter(
              level: () => controller.levelForTrack(trackId),
              repaint: controller,
            ),
          ),
        ),
      ),
    );
  }
}

class MasterStereoMeter extends StatelessWidget {
  const MasterStereoMeter({super.key, required this.controller});

  final AudioMeterController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: 'Master stereo level meter',
        child: SizedBox(
          key: const ValueKey('master-level-meter'),
          width: 168,
          height: 48,
          child: CustomPaint(
            painter: _MasterMeterPainter(
              level: () => controller.masterLevel,
              repaint: controller,
              colorScheme: Theme.of(context).colorScheme,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackMeterPainter extends CustomPainter {
  _TrackMeterPainter({required this.level, required super.repaint});

  final StereoMeterLevel Function() level;

  @override
  void paint(Canvas canvas, Size size) {
    final current = level();
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xFF101318));
    canvas.drawRRect(
      background.deflate(0.5),
      Paint()
        ..color = const Color(0xFF414852)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    const top = 10.0;
    final barHeight = size.height - top - 4;
    const channelWidth = 5.0;
    const gap = 2.0;
    final left = (size.width - channelWidth * 2 - gap) / 2;
    _paintVerticalChannel(
      canvas,
      Rect.fromLTWH(left, top, channelWidth, barHeight),
      db: current.leftDb,
      peakDb: current.leftPeakDb,
      clipped: current.leftClipped,
    );
    _paintVerticalChannel(
      canvas,
      Rect.fromLTWH(left + channelWidth + gap, top, channelWidth, barHeight),
      db: current.rightDb,
      peakDb: current.rightPeakDb,
      clipped: current.rightClipped,
    );
    _paintText(canvas, 'L', Offset(left - 0.5, 1), fontSize: 7);
    _paintText(
      canvas,
      'R',
      Offset(left + channelWidth + gap - 0.5, 1),
      fontSize: 7,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackMeterPainter oldDelegate) => false;
}

class _MasterMeterPainter extends CustomPainter {
  _MasterMeterPainter({
    required this.level,
    required this.colorScheme,
    required super.repaint,
  });

  final StereoMeterLevel Function() level;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final current = level();
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      background,
      Paint()..color = colorScheme.surfaceContainerLow,
    );
    canvas.drawRRect(
      background.deflate(0.5),
      Paint()
        ..color = colorScheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _paintText(
      canvas,
      'MASTER',
      const Offset(9, 4),
      color: colorScheme.onSurfaceVariant,
      fontSize: 8,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    final clipped = current.leftClipped || current.rightClipped;
    canvas.drawCircle(
      const Offset(156, 9),
      3,
      Paint()
        ..color = clipped ? const Color(0xFFFF5252) : const Color(0xFF3B2428),
    );

    const barLeft = 20.0;
    const barWidth = 105.0;
    const barHeight = 7.0;
    _paintText(canvas, 'L', const Offset(8, 17), fontSize: 8);
    _paintText(canvas, 'R', const Offset(8, 31), fontSize: 8);
    _paintHorizontalChannel(
      canvas,
      const Rect.fromLTWH(barLeft, 18, barWidth, barHeight),
      db: current.leftDb,
      peakDb: current.leftPeakDb,
      clipped: current.leftClipped,
    );
    _paintHorizontalChannel(
      canvas,
      const Rect.fromLTWH(barLeft, 32, barWidth, barHeight),
      db: current.rightDb,
      peakDb: current.rightPeakDb,
      clipped: current.rightClipped,
    );
    _paintText(
      canvas,
      _formatDb(current.leftDb),
      const Offset(132, 16),
      color: colorScheme.onSurfaceVariant,
      fontSize: 8,
    );
    _paintText(
      canvas,
      _formatDb(current.rightDb),
      const Offset(132, 30),
      color: colorScheme.onSurfaceVariant,
      fontSize: 8,
    );
  }

  @override
  bool shouldRepaint(covariant _MasterMeterPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}

const _meterGradientColors = [
  Color(0xFF34C77B),
  Color(0xFF9CCB42),
  Color(0xFFF1C84B),
  Color(0xFFFF5C57),
];
const _meterGradientStops = [0.0, 0.66, 0.87, 1.0];

void _paintVerticalChannel(
  Canvas canvas,
  Rect rect, {
  required double db,
  required double peakDb,
  required bool clipped,
}) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
    Paint()..color = const Color(0xFF07090C),
  );
  final fraction = _meterFraction(db);
  if (fraction > 0) {
    final activeRect = Rect.fromLTRB(
      rect.left,
      rect.bottom - rect.height * fraction,
      rect.right,
      rect.bottom,
    );
    canvas.drawRect(
      activeRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: _meterGradientColors,
          stops: _meterGradientStops,
        ).createShader(rect),
    );
  }
  final peakFraction = _meterFraction(peakDb);
  if (peakFraction > 0) {
    final y = rect.bottom - rect.height * peakFraction;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, y - 0.5, rect.width, 1),
      Paint()..color = clipped ? const Color(0xFFFF5252) : Colors.white70,
    );
  }
  if (clipped) {
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, 2),
      Paint()..color = const Color(0xFFFF3B3B),
    );
  }
}

void _paintHorizontalChannel(
  Canvas canvas,
  Rect rect, {
  required double db,
  required double peakDb,
  required bool clipped,
}) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(2)),
    Paint()..color = const Color(0xFF07090C),
  );
  final fraction = _meterFraction(db);
  if (fraction > 0) {
    final activeRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width * fraction,
      rect.height,
    );
    canvas.drawRect(
      activeRect,
      Paint()
        ..shader = const LinearGradient(
          colors: _meterGradientColors,
          stops: _meterGradientStops,
        ).createShader(rect),
    );
  }
  final peakFraction = _meterFraction(peakDb);
  if (peakFraction > 0) {
    final x = rect.left + rect.width * peakFraction;
    canvas.drawRect(
      Rect.fromLTWH(x - 0.5, rect.top, 1, rect.height),
      Paint()..color = clipped ? const Color(0xFFFF5252) : Colors.white70,
    );
  }
}

double _meterFraction(double db) =>
    ((db - meterFloorDb) / -meterFloorDb).clamp(0.0, 1.0).toDouble();

String _formatDb(double db) {
  if (db <= meterFloorDb) {
    return '-∞';
  }
  return math.max(-99, db).round().toString();
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  Color color = const Color(0xFFAAB1BA),
  double fontSize = 8,
  FontWeight fontWeight = FontWeight.w700,
  double? letterSpacing,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}
