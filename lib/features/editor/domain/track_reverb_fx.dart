import 'dart:math' as math;

const double minimumReverbPreDelaySeconds = 0;
const double maximumReverbPreDelaySeconds = 0.2;
const double defaultReverbPreDelaySeconds = 0.020;
const double minimumReverbDecaySeconds = 0.2;
const double maximumReverbDecaySeconds = 10;
const double defaultReverbDecaySeconds = 1.8;
const double minimumReverbDampingHz = 1000;
const double maximumReverbDampingHz = 20000;
const double defaultReverbDampingHz = 8000;
const double minimumReverbMix = 0;
const double maximumReverbMix = 1;
const double defaultReverbMix = 0.20;
const double maximumReverbTailSeconds = 12;
const double maximumCombinedTrackFxTailSeconds = 15;
const double reverbTailSafetySeconds = 0.25;

enum TrackReverbParameter { preDelay, decay, damping, mix }

class TrackReverbFx {
  const TrackReverbFx({
    this.enabled = false,
    this.preDelaySeconds = defaultReverbPreDelaySeconds,
    this.decaySeconds = defaultReverbDecaySeconds,
    this.dampingHz = defaultReverbDampingHz,
    this.mix = defaultReverbMix,
  });

  final bool enabled;
  final double preDelaySeconds;
  final double decaySeconds;
  final double dampingHz;
  final double mix;

  TrackReverbFx copyWith({
    bool? enabled,
    double? preDelaySeconds,
    double? decaySeconds,
    double? dampingHz,
    double? mix,
  }) {
    return TrackReverbFx(
      enabled: enabled ?? this.enabled,
      preDelaySeconds: clampReverbPreDelaySeconds(
        preDelaySeconds ?? this.preDelaySeconds,
      ),
      decaySeconds: clampReverbDecaySeconds(decaySeconds ?? this.decaySeconds),
      dampingHz: clampReverbDampingHz(dampingHz ?? this.dampingHz),
      mix: clampReverbMix(mix ?? this.mix),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackReverbFx &&
      enabled == other.enabled &&
      preDelaySeconds == other.preDelaySeconds &&
      decaySeconds == other.decaySeconds &&
      dampingHz == other.dampingHz &&
      mix == other.mix;

  @override
  int get hashCode =>
      Object.hash(enabled, preDelaySeconds, decaySeconds, dampingHz, mix);
}

double reverbDryGain(double mix) => math.cos(clampReverbMix(mix) * math.pi / 2);

double reverbWetGain(double mix) => math.sin(clampReverbMix(mix) * math.pi / 2);

double estimateReverbTailSeconds(TrackReverbFx reverb) {
  if (!reverb.enabled || clampReverbMix(reverb.mix) <= 0) return 0;
  return (clampReverbPreDelaySeconds(reverb.preDelaySeconds) +
          clampReverbDecaySeconds(reverb.decaySeconds) +
          reverbTailSafetySeconds)
      .clamp(0, maximumReverbTailSeconds);
}

double clampReverbPreDelaySeconds(double value) => _clampFinite(
  value,
  minimumReverbPreDelaySeconds,
  maximumReverbPreDelaySeconds,
  defaultReverbPreDelaySeconds,
);

double clampReverbDecaySeconds(double value) => _clampFinite(
  value,
  minimumReverbDecaySeconds,
  maximumReverbDecaySeconds,
  defaultReverbDecaySeconds,
);

double clampReverbDampingHz(double value) => _clampFinite(
  value,
  minimumReverbDampingHz,
  maximumReverbDampingHz,
  defaultReverbDampingHz,
);

double clampReverbMix(double value) =>
    _clampFinite(value, minimumReverbMix, maximumReverbMix, defaultReverbMix);

double _clampFinite(
  double value,
  double minimum,
  double maximum,
  double fallback,
) {
  if (!value.isFinite) return fallback;
  return value.clamp(minimum, maximum);
}

String formatReverbPreDelay(double seconds) =>
    '${(clampReverbPreDelaySeconds(seconds) * 1000).round()} ms';

String formatReverbDecay(double seconds) =>
    '${clampReverbDecaySeconds(seconds).toStringAsFixed(1)} s';

String formatReverbDamping(double hertz) =>
    '${(clampReverbDampingHz(hertz) / 1000).toStringAsFixed(1)} kHz';

String formatReverbMix(double mix) => '${(clampReverbMix(mix) * 100).round()}%';
