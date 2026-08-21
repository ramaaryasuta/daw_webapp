import 'dart:math' as math;

/// Shared coordinate system for every time-based element in the editor.
class TimelineScale {
  const TimelineScale(this.pixelsPerSecond);

  static const double defaultPixelsPerSecond = 100;
  static const double minPixelsPerSecond = 2;
  static const double maxPixelsPerSecond = 1200;

  static const List<double> tickIntervalsSeconds = <double>[
    0.1,
    0.25,
    0.5,
    1,
    2,
    5,
    10,
    30,
    60,
  ];

  final double pixelsPerSecond;

  double timeToPixels(Duration time) {
    return time.inMicroseconds /
        Duration.microsecondsPerSecond *
        pixelsPerSecond;
  }

  Duration pixelsToTime(double pixels) {
    return Duration(
      microseconds: (pixelsToSeconds(pixels) * Duration.microsecondsPerSecond)
          .round(),
    );
  }

  double secondsToPixels(double seconds) => seconds * pixelsPerSecond;

  double pixelsToSeconds(double pixels) => pixels / pixelsPerSecond;

  double scrollOffsetKeepingAnchor({
    required TimelineScale newScale,
    required double currentScrollOffset,
    required double viewportX,
  }) {
    return TimelineTransform(
      scale: this,
      horizontalScrollOffset: currentScrollOffset,
    ).scrollOffsetKeepingAnchor(newScale: newScale, viewportX: viewportX);
  }

  /// Chooses the interval whose rendered width is closest to a readable target.
  double get majorTickIntervalSeconds {
    const targetSpacing = 110.0;

    return tickIntervalsSeconds.reduce((best, candidate) {
      final bestDistance = (best * pixelsPerSecond - targetSpacing).abs();
      final candidateDistance = (candidate * pixelsPerSecond - targetSpacing)
          .abs();

      return candidateDistance < bestDistance ? candidate : best;
    });
  }

  int get minorDivisions => 5;

  double get minorTickIntervalSeconds {
    return majorTickIntervalSeconds / minorDivisions;
  }

  double timelineContentWidth({
    required double durationSeconds,
    required double viewportWidth,
    double trailingPaddingSeconds = 2,
  }) {
    if (durationSeconds <= 0) {
      return viewportWidth;
    }

    return math.max(
      viewportWidth,
      secondsToPixels(durationSeconds + trailingPaddingSeconds),
    );
  }

  String formatTickLabel(double seconds) {
    final totalMilliseconds = (seconds * 1000).round();
    final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
    final minutes = (totalMilliseconds ~/ Duration.millisecondsPerMinute) % 60;
    final wholeSeconds =
        (totalMilliseconds ~/ Duration.millisecondsPerSecond) % 60;
    final milliseconds = totalMilliseconds % 1000;

    final prefix = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final base =
        '$prefix${minutes.toString().padLeft(2, '0')}:'
        '${wholeSeconds.toString().padLeft(2, '0')}';

    if (majorTickIntervalSeconds < 1) {
      return '$base.${milliseconds.toString().padLeft(3, '0')}';
    }

    return base;
  }

  static double clampPixelsPerSecond(double value) {
    return value.clamp(minPixelsPerSecond, maxPixelsPerSecond).toDouble();
  }
}

/// Converts between timeline content coordinates and the visible viewport.
///
/// Content X is independent of scrolling. Viewport X has the horizontal scroll
/// offset removed and is therefore suitable for pointer anchors and follow
/// calculations.
class TimelineTransform {
  const TimelineTransform({
    required this.scale,
    this.horizontalScrollOffset = 0,
  });

  final TimelineScale scale;
  final double horizontalScrollOffset;

  double timeToContentX(double seconds) => scale.secondsToPixels(seconds);

  double contentXToTime(double contentX) => scale.pixelsToSeconds(contentX);

  double contentToViewportX(double contentX) {
    return contentX - horizontalScrollOffset;
  }

  double viewportToContentX(double viewportX) {
    return viewportX + horizontalScrollOffset;
  }

  double timeToViewportX(double seconds) {
    return contentToViewportX(timeToContentX(seconds));
  }

  double viewportXToTime(double viewportX) {
    return contentXToTime(viewportToContentX(viewportX));
  }

  double scrollOffsetKeepingAnchor({
    required TimelineScale newScale,
    required double viewportX,
  }) {
    final timeUnderAnchor = viewportXToTime(viewportX);

    return newScale.secondsToPixels(timeUnderAnchor) - viewportX;
  }
}

class TimelineTick {
  const TimelineTick({
    required this.index,
    required this.timeSeconds,
    required this.contentX,
    required this.isMajor,
  });

  final int index;
  final double timeSeconds;
  final double contentX;
  final bool isMajor;
}

/// Shared adaptive tick boundaries and paint coordinates for ruler and grid.
class TimelineGridMetrics {
  const TimelineGridMetrics({required this.transform});

  final TimelineTransform transform;

  TimelineScale get scale => transform.scale;

  double get majorTickIntervalSeconds => scale.majorTickIntervalSeconds;

  int get minorDivisions => scale.minorDivisions;

  double get minorTickIntervalSeconds {
    return scale.minorTickIntervalSeconds;
  }

  double get minorTickSpacing {
    return transform.timeToContentX(minorTickIntervalSeconds);
  }

  Iterable<TimelineTick> ticksInContentRange({
    required double left,
    required double right,
    required double contentWidth,
  }) sync* {
    final spacing = minorTickSpacing;
    final firstIndex = math.max(0, (left / spacing).floor() - 1);
    final lastIndex = math.min(
      (contentWidth / spacing).ceil(),
      (right / spacing).ceil() + 1,
    );

    for (var index = firstIndex; index <= lastIndex; index++) {
      final seconds = index * minorTickIntervalSeconds;

      yield TimelineTick(
        index: index,
        timeSeconds: seconds,
        contentX: transform.timeToContentX(seconds),
        isMajor: index % minorDivisions == 0,
      );
    }
  }

  /// Places a stroke so its edges share the same physical-pixel alignment in
  /// every timeline painter. This is applied only after the logical content X
  /// has been calculated by [TimelineTransform].
  double alignStrokeCenter(
    double contentX, {
    required double devicePixelRatio,
    double strokeWidth = 1,
  }) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      return contentX;
    }

    final physicalLeft = (contentX - strokeWidth / 2) * devicePixelRatio;

    return physicalLeft.round() / devicePixelRatio + strokeWidth / 2;
  }
}
