import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints viewport-filling arrangement lanes without creating project tracks
/// or adding items to either vertical scroll view.
class TrackLaneBackgroundPainter extends CustomPainter {
  const TrackLaneBackgroundPainter({
    required this.baseColor,
    required this.alternateColor,
    required this.separatorColor,
    required this.rowHeight,
    required this.scrollOffset,
    required this.devicePixelRatio,
  });

  final Color baseColor;
  final Color alternateColor;
  final Color separatorColor;
  final double rowHeight;
  final double scrollOffset;
  final double devicePixelRatio;

  Iterable<({int index, Rect rect})> lanesForSize(Size size) sync* {
    if (size.isEmpty || !rowHeight.isFinite || rowHeight <= 0) {
      return;
    }

    final offset = scrollOffset.isFinite ? math.max(0.0, scrollOffset) : 0.0;
    final firstIndex = (offset / rowHeight).floor();
    var top = firstIndex * rowHeight - offset;
    var index = firstIndex;

    while (top < size.height) {
      yield (index: index, rect: Rect.fromLTWH(0, top, size.width, rowHeight));
      top += rowHeight;
      index++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = 1;

    for (final lane in lanesForSize(size)) {
      canvas.drawRect(
        lane.rect,
        Paint()..color = lane.index.isEven ? baseColor : alternateColor,
      );
      final separatorY = _alignStrokeCenter(lane.rect.bottom);
      canvas.drawLine(
        Offset(0, separatorY),
        Offset(size.width, separatorY),
        separatorPaint,
      );
    }
  }

  double _alignStrokeCenter(double logicalY) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      return logicalY;
    }
    return ((logicalY - 0.5) * devicePixelRatio).round() / devicePixelRatio +
        0.5;
  }

  @override
  bool shouldRepaint(covariant TrackLaneBackgroundPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.alternateColor != alternateColor ||
        oldDelegate.separatorColor != separatorColor ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
