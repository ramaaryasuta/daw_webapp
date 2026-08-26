import 'dart:math' as math;

/// Smallest freely positioned transport loop allowed by the editor.
const double minimumLoopDurationSeconds = 0.075;

/// A transport cycle range stored in absolute project-timeline seconds.
class LoopRegion {
  const LoopRegion({required this.startSeconds, required this.endSeconds})
    : assert(startSeconds >= 0 && startSeconds < double.infinity),
      assert(endSeconds > startSeconds && endSeconds < double.infinity);

  final double startSeconds;
  final double endSeconds;

  double get durationSeconds => endSeconds - startSeconds;

  bool contains(double seconds) {
    return seconds >= startSeconds && seconds < endSeconds;
  }

  static LoopRegion normalized({
    required double firstSeconds,
    required double secondSeconds,
    double minimumDurationSeconds = minimumLoopDurationSeconds,
  }) {
    final minimum =
        minimumDurationSeconds.isFinite && minimumDurationSeconds > 0
        ? minimumDurationSeconds
        : minimumLoopDurationSeconds;
    final first = math.max(0.0, firstSeconds.isFinite ? firstSeconds : 0.0);
    final second = math.max(0.0, secondSeconds.isFinite ? secondSeconds : 0.0);
    var start = math.min(first, second);
    var end = math.max(first, second);

    if (end - start < minimum) {
      if (second < first) {
        start = math.max(0.0, end - minimum);
        end = start + minimum;
      } else {
        end = start + minimum;
      }
    }

    return LoopRegion(startSeconds: start, endSeconds: end);
  }

  @override
  bool operator ==(Object other) {
    return other is LoopRegion &&
        other.startSeconds == startSeconds &&
        other.endSeconds == endSeconds;
  }

  @override
  int get hashCode => Object.hash(startSeconds, endSeconds);
}
