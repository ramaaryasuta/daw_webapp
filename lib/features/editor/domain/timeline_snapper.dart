import 'dart:math' as math;

import 'musical_timing.dart';
import 'snap_settings.dart';

abstract final class TimelineSnapper {
  static double subdivisionBeats(
    SnapSubdivision subdivision, {
    int beatsPerBar = defaultBeatsPerBar,
  }) {
    if (beatsPerBar <= 0) {
      throw ArgumentError.value(
        beatsPerBar,
        'beatsPerBar',
        'Must be greater than 0',
      );
    }

    return switch (subdivision) {
      SnapSubdivision.bar => beatsPerBar.toDouble(),
      SnapSubdivision.beat => 1,
      SnapSubdivision.halfBeat => 1 / 2,
      SnapSubdivision.quarterBeat => 1 / 4,
      SnapSubdivision.eighthBeat => 1 / 8,
    };
  }

  static double intervalSeconds({
    required double bpm,
    required SnapSubdivision subdivision,
    int beatsPerBar = defaultBeatsPerBar,
  }) {
    return MusicalTiming(
          bpm: bpm,
          beatsPerBar: beatsPerBar,
        ).beatDurationSeconds *
        subdivisionBeats(subdivision, beatsPerBar: beatsPerBar);
  }

  /// Returns the nearest musical grid time using a direct grid index.
  ///
  /// The result is always clamped to timeline zero. Disabled settings return
  /// the unclipped candidate (also clamped to zero).
  static double snapTime({
    required double candidateSeconds,
    required double bpm,
    required SnapSettings settings,
    int beatsPerBar = defaultBeatsPerBar,
  }) {
    if (!candidateSeconds.isFinite) {
      return 0;
    }

    final candidate = math.max(0.0, candidateSeconds);
    if (!settings.enabled) {
      return candidate;
    }

    final interval = intervalSeconds(
      bpm: bpm,
      subdivision: settings.subdivision,
      beatsPerBar: beatsPerBar,
    );
    final gridIndex = (candidate / interval).round();
    final snapped = gridIndex * interval;

    // Normalize tiny negative zero/rounding artifacts at the timeline origin.
    return snapped <= 0 ? 0 : snapped;
  }
}
