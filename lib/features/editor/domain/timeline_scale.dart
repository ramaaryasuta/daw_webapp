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
    final timeUnderAnchor = pixelsToSeconds(currentScrollOffset + viewportX);

    return newScale.secondsToPixels(timeUnderAnchor) - viewportX;
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
