import 'dart:math' as math;

const double minimumCompressorThresholdDb = -60;
const double maximumCompressorThresholdDb = 0;
const double defaultCompressorThresholdDb = -18;
const double minimumCompressorRatio = 1;
const double maximumCompressorRatio = 20;
const double defaultCompressorRatio = 4;
const double minimumCompressorAttackSeconds = 0.001;
const double maximumCompressorAttackSeconds = 0.2;
const double defaultCompressorAttackSeconds = 0.01;
const double minimumCompressorReleaseSeconds = 0.02;
const double maximumCompressorReleaseSeconds = 2;
const double defaultCompressorReleaseSeconds = 0.25;
const double minimumCompressorMakeupGainDb = -12;
const double maximumCompressorMakeupGainDb = 12;
const double defaultCompressorMakeupGainDb = 0;

enum TrackCompressorParameter { threshold, ratio, attack, release, makeupGain }

class TrackCompressorFx {
  const TrackCompressorFx({
    this.enabled = false,
    this.thresholdDb = defaultCompressorThresholdDb,
    this.ratio = defaultCompressorRatio,
    this.attackSeconds = defaultCompressorAttackSeconds,
    this.releaseSeconds = defaultCompressorReleaseSeconds,
    this.makeupGainDb = defaultCompressorMakeupGainDb,
  });

  final bool enabled;
  final double thresholdDb;
  final double ratio;
  final double attackSeconds;
  final double releaseSeconds;
  final double makeupGainDb;

  TrackCompressorFx copyWith({
    bool? enabled,
    double? thresholdDb,
    double? ratio,
    double? attackSeconds,
    double? releaseSeconds,
    double? makeupGainDb,
  }) {
    return TrackCompressorFx(
      enabled: enabled ?? this.enabled,
      thresholdDb: clampCompressorThresholdDb(thresholdDb ?? this.thresholdDb),
      ratio: clampCompressorRatio(ratio ?? this.ratio),
      attackSeconds: clampCompressorAttackSeconds(
        attackSeconds ?? this.attackSeconds,
      ),
      releaseSeconds: clampCompressorReleaseSeconds(
        releaseSeconds ?? this.releaseSeconds,
      ),
      makeupGainDb: clampCompressorMakeupGainDb(
        makeupGainDb ?? this.makeupGainDb,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackCompressorFx &&
      enabled == other.enabled &&
      thresholdDb == other.thresholdDb &&
      ratio == other.ratio &&
      attackSeconds == other.attackSeconds &&
      releaseSeconds == other.releaseSeconds &&
      makeupGainDb == other.makeupGainDb;

  @override
  int get hashCode => Object.hash(
    enabled,
    thresholdDb,
    ratio,
    attackSeconds,
    releaseSeconds,
    makeupGainDb,
  );
}

double clampCompressorThresholdDb(double value) => _clampFinite(
  value,
  minimumCompressorThresholdDb,
  maximumCompressorThresholdDb,
  defaultCompressorThresholdDb,
);

double clampCompressorRatio(double value) => _clampFinite(
  value,
  minimumCompressorRatio,
  maximumCompressorRatio,
  defaultCompressorRatio,
);

double clampCompressorAttackSeconds(double value) => _clampFinite(
  value,
  minimumCompressorAttackSeconds,
  maximumCompressorAttackSeconds,
  defaultCompressorAttackSeconds,
);

double clampCompressorReleaseSeconds(double value) => _clampFinite(
  value,
  minimumCompressorReleaseSeconds,
  maximumCompressorReleaseSeconds,
  defaultCompressorReleaseSeconds,
);

double clampCompressorMakeupGainDb(double value) => _clampFinite(
  value,
  minimumCompressorMakeupGainDb,
  maximumCompressorMakeupGainDb,
  defaultCompressorMakeupGainDb,
);

double compressorMakeupDbToLinear(double db) =>
    math.pow(10, clampCompressorMakeupGainDb(db) / 20).toDouble();

double _clampFinite(
  double value,
  double minimum,
  double maximum,
  double fallback,
) {
  if (!value.isFinite) return fallback;
  return value.clamp(minimum, maximum);
}

String formatCompressorThreshold(double value) =>
    '${clampCompressorThresholdDb(value).toStringAsFixed(1)} dB';

String formatCompressorRatio(double value) =>
    '${clampCompressorRatio(value).toStringAsFixed(1)}:1';

String formatCompressorAttack(double seconds) =>
    '${(clampCompressorAttackSeconds(seconds) * 1000).round()} ms';

String formatCompressorRelease(double seconds) {
  final value = clampCompressorReleaseSeconds(seconds);
  if (value < 1) return '${(value * 1000).round()} ms';
  return '${value.toStringAsFixed(2)} s';
}

String formatCompressorMakeup(double value) {
  final gain = clampCompressorMakeupGainDb(value);
  final prefix = gain > 0 ? '+' : '';
  return '$prefix${gain.toStringAsFixed(1)} dB';
}
