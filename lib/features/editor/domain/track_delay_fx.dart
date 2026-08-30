import 'dart:math' as math;

import 'musical_timing.dart';

const double minimumDelayTimeSeconds = 0.010;
const double maximumDelayTimeSeconds = 2.0;
const double maximumSynchronizedDelayTimeSeconds = 5.0;
const double defaultDelayTimeSeconds = 0.35;
const double minimumDelayFeedback = 0;
const double maximumDelayFeedback = 0.90;
const double defaultDelayFeedback = 0.35;
const double minimumDelayMix = 0;
const double maximumDelayMix = 1;
const double defaultDelayMix = 0.25;
const double delayTailAmplitudeThreshold = 0.001;
const double maximumDelayTailSeconds = 12;

enum DelaySyncDivision {
  quarter('1/4', 1),
  eighth('1/8', 0.5),
  sixteenth('1/16', 0.25),
  dottedEighth('1/8 D', 0.75),
  dottedQuarter('1/4 D', 1.5);

  const DelaySyncDivision(this.label, this.quarterNoteMultiplier);

  final String label;
  final double quarterNoteMultiplier;
}

enum TrackDelayParameter { time, feedback, mix }

class TrackDelayFx {
  const TrackDelayFx({
    this.enabled = false,
    this.syncToBpm = false,
    this.timeSeconds = defaultDelayTimeSeconds,
    this.syncDivision = DelaySyncDivision.quarter,
    this.feedback = defaultDelayFeedback,
    this.mix = defaultDelayMix,
  });

  final bool enabled;
  final bool syncToBpm;
  final double timeSeconds;
  final DelaySyncDivision syncDivision;
  final double feedback;
  final double mix;

  TrackDelayFx copyWith({
    bool? enabled,
    bool? syncToBpm,
    double? timeSeconds,
    DelaySyncDivision? syncDivision,
    double? feedback,
    double? mix,
  }) {
    return TrackDelayFx(
      enabled: enabled ?? this.enabled,
      syncToBpm: syncToBpm ?? this.syncToBpm,
      timeSeconds: clampDelayTimeSeconds(timeSeconds ?? this.timeSeconds),
      syncDivision: syncDivision ?? this.syncDivision,
      feedback: clampDelayFeedback(feedback ?? this.feedback),
      mix: clampDelayMix(mix ?? this.mix),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackDelayFx &&
      enabled == other.enabled &&
      syncToBpm == other.syncToBpm &&
      timeSeconds == other.timeSeconds &&
      syncDivision == other.syncDivision &&
      feedback == other.feedback &&
      mix == other.mix;

  @override
  int get hashCode =>
      Object.hash(enabled, syncToBpm, timeSeconds, syncDivision, feedback, mix);
}

double delayTimeForDivision(double bpm, DelaySyncDivision division) =>
    (secondsPerQuarterNote(bpm) * division.quarterNoteMultiplier).clamp(
      minimumDelayTimeSeconds,
      maximumSynchronizedDelayTimeSeconds,
    );

double effectiveDelayTimeSeconds(TrackDelayFx delay, double bpm) =>
    delay.syncToBpm
    ? delayTimeForDivision(bpm, delay.syncDivision)
    : clampDelayTimeSeconds(delay.timeSeconds);

double delayDryGain(double mix) => math.cos(clampDelayMix(mix) * math.pi / 2);

double delayWetGain(double mix) => math.sin(clampDelayMix(mix) * math.pi / 2);

double estimateDelayTailSeconds(TrackDelayFx delay, double bpm) {
  final feedback = clampDelayFeedback(delay.feedback);
  if (!delay.enabled || clampDelayMix(delay.mix) <= 0 || feedback <= 0) {
    return 0;
  }
  // Estimate repeats until feedback falls below -60 dB, then cap pathological
  // settings so live playback and offline export have a finite tail horizon.
  final repeats = math.max(
    1,
    (math.log(delayTailAmplitudeThreshold) / math.log(feedback)).ceil(),
  );
  return (repeats * effectiveDelayTimeSeconds(delay, bpm)).clamp(
    0,
    maximumDelayTailSeconds,
  );
}

double clampDelayTimeSeconds(double value) => _clampFinite(
  value,
  minimumDelayTimeSeconds,
  maximumDelayTimeSeconds,
  defaultDelayTimeSeconds,
);

double clampDelayFeedback(double value) => _clampFinite(
  value,
  minimumDelayFeedback,
  maximumDelayFeedback,
  defaultDelayFeedback,
);

double clampDelayMix(double value) =>
    _clampFinite(value, minimumDelayMix, maximumDelayMix, defaultDelayMix);

double _clampFinite(
  double value,
  double minimum,
  double maximum,
  double fallback,
) {
  if (!value.isFinite) return fallback;
  return value.clamp(minimum, maximum);
}

String formatDelayTime(double seconds) {
  final value = clampDelayTimeSeconds(seconds);
  if (value < 1) return '${(value * 1000).round()} ms';
  return '${value.toStringAsFixed(2)} s';
}

String formatDelayPercent(double value) {
  final normalized = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
  return '${(normalized * 100).round()}%';
}
