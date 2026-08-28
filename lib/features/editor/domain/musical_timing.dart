import 'dart:math' as math;

/// A single project-wide musical meter.
class TimeSignature {
  const TimeSignature({required this.numerator, required this.denominator})
    : assert(numerator > 0),
      assert(denominator > 0);

  static const commonTime = TimeSignature(numerator: 4, denominator: 4);
  static const threeFour = TimeSignature(numerator: 3, denominator: 4);
  static const sixEight = TimeSignature(numerator: 6, denominator: 8);

  static const supported = <TimeSignature>[commonTime, threeFour, sixEight];

  final int numerator;
  final int denominator;

  String get label => '$numerator/$denominator';

  bool get isSupported => supported.contains(this);

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => label;
}

const TimeSignature defaultTimeSignature = TimeSignature.commonTime;

double secondsPerQuarterNote(double bpm) {
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
  MusicalTiming({
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
  }) {
    secondsPerQuarterNote(bpm);
  }

  final double bpm;
  final TimeSignature timeSignature;

  int get beatsPerBar => timeSignature.numerator;

  double get quarterNoteSeconds => secondsPerQuarterNote(bpm);

  double get beatSeconds =>
      quarterNoteSeconds * (4 / timeSignature.denominator);

  double get barSeconds => beatSeconds * beatsPerBar;

  double get beatDurationSeconds => beatSeconds;

  double get barDurationSeconds => barSeconds;

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
