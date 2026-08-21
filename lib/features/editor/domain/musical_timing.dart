import 'dart:math' as math;

/// Default project meter used by the metronome and musical timeline grid.
///
/// Keeping this in the domain layer allows a future time-signature model to
/// replace the default without coupling editor features to the audio engine.
const int defaultBeatsPerBar = 4;

double secondsPerBeat(double bpm) {
  if (!bpm.isFinite || bpm <= 0) {
    throw ArgumentError.value(bpm, 'bpm', 'Must be finite and greater than 0');
  }

  return 60 / bpm;
}

/// A user-facing, one-based position in the musical timeline.
class MusicalPosition {
  const MusicalPosition({required this.bar, required this.beat});

  final int bar;
  final int beat;

  String get label => '$bar:$beat';

  @override
  String toString() => label;
}

/// Shared musical coordinate system for snap, grid, ruler, and metronome.
///
/// Integer beat indices are zero-based and all originate at timeline zero.
/// User-facing [MusicalPosition] values are one-based, so beat index zero is
/// always bar 1, beat 1.
class MusicalTiming {
  MusicalTiming({required this.bpm, this.beatsPerBar = defaultBeatsPerBar}) {
    secondsPerBeat(bpm);
    if (beatsPerBar <= 0) {
      throw ArgumentError.value(
        beatsPerBar,
        'beatsPerBar',
        'Must be greater than 0',
      );
    }
  }

  final double bpm;
  final int beatsPerBar;

  double get beatDurationSeconds => secondsPerBeat(bpm);

  double get barDurationSeconds => beatDurationSeconds * beatsPerBar;

  double beatTimeSeconds(int beatIndex) {
    return math.max(0, beatIndex) * beatDurationSeconds;
  }

  int beatIndexAtTime(double timelineSeconds) {
    if (!timelineSeconds.isFinite || timelineSeconds <= 0) {
      return 0;
    }
    return (timelineSeconds / beatDurationSeconds).floor();
  }

  int firstBeatIndexAtOrAfter(double timelineSeconds, {double epsilon = 1e-9}) {
    if (!timelineSeconds.isFinite || timelineSeconds <= 0) {
      return 0;
    }
    return math.max(
      0,
      (timelineSeconds / beatDurationSeconds - epsilon).ceil(),
    );
  }

  MusicalPosition positionAtBeatIndex(int beatIndex) {
    final normalizedIndex = math.max(0, beatIndex);
    return MusicalPosition(
      bar: normalizedIndex ~/ beatsPerBar + 1,
      beat: normalizedIndex % beatsPerBar + 1,
    );
  }

  MusicalPosition positionAtTime(double timelineSeconds) {
    return positionAtBeatIndex(beatIndexAtTime(timelineSeconds));
  }

  double musicalPositionToTime(MusicalPosition position) {
    if (position.bar <= 0 ||
        position.beat <= 0 ||
        position.beat > beatsPerBar) {
      throw ArgumentError.value(position, 'position', 'Invalid bar or beat');
    }
    final beatIndex = (position.bar - 1) * beatsPerBar + (position.beat - 1);
    return beatTimeSeconds(beatIndex);
  }

  bool isDownbeat(int beatIndex) => beatIndex % beatsPerBar == 0;
}
