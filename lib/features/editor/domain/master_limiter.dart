import 'dart:math' as math;
import 'dart:typed_data';

const double minimumMasterLimiterThresholdDb = -24;
const double maximumMasterLimiterThresholdDb = 0;
const double defaultMasterLimiterThresholdDb = -3;

const double minimumMasterLimiterCeilingDb = -6;
const double maximumMasterLimiterCeilingDb = 0;
const double defaultMasterLimiterCeilingDb = -1;

const double minimumMasterLimiterReleaseSeconds = 0.020;
const double maximumMasterLimiterReleaseSeconds = 1;
const double defaultMasterLimiterReleaseSeconds = 0.120;

const double masterLimiterRatio = 20;
const double masterLimiterKneeDb = 0;
const double masterLimiterAttackSeconds = 0.002;
const int masterLimiterCeilingCurveLength = 4096;

enum MasterLimiterParameter { threshold, ceiling, release }

class MasterLimiterSettings {
  const MasterLimiterSettings({
    this.enabled = false,
    this.thresholdDb = defaultMasterLimiterThresholdDb,
    this.ceilingDb = defaultMasterLimiterCeilingDb,
    this.releaseSeconds = defaultMasterLimiterReleaseSeconds,
  });

  final bool enabled;
  final double thresholdDb;
  final double ceilingDb;
  final double releaseSeconds;

  MasterLimiterSettings copyWith({
    bool? enabled,
    double? thresholdDb,
    double? ceilingDb,
    double? releaseSeconds,
  }) {
    return MasterLimiterSettings(
      enabled: enabled ?? this.enabled,
      thresholdDb: thresholdDb ?? this.thresholdDb,
      ceilingDb: ceilingDb ?? this.ceilingDb,
      releaseSeconds: releaseSeconds ?? this.releaseSeconds,
    ).clamped();
  }

  MasterLimiterSettings clamped() => MasterLimiterSettings(
    enabled: enabled,
    thresholdDb: clampMasterLimiterThresholdDb(thresholdDb),
    ceilingDb: clampMasterLimiterCeilingDb(ceilingDb),
    releaseSeconds: clampMasterLimiterReleaseSeconds(releaseSeconds),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterLimiterSettings &&
          enabled == other.enabled &&
          thresholdDb == other.thresholdDb &&
          ceilingDb == other.ceilingDb &&
          releaseSeconds == other.releaseSeconds;

  @override
  int get hashCode =>
      Object.hash(enabled, thresholdDb, ceilingDb, releaseSeconds);
}

double clampMasterLimiterThresholdDb(double value) => _finiteClamp(
  value,
  minimumMasterLimiterThresholdDb,
  maximumMasterLimiterThresholdDb,
  defaultMasterLimiterThresholdDb,
);

double clampMasterLimiterCeilingDb(double value) => _finiteClamp(
  value,
  minimumMasterLimiterCeilingDb,
  maximumMasterLimiterCeilingDb,
  defaultMasterLimiterCeilingDb,
);

double clampMasterLimiterReleaseSeconds(double value) => _finiteClamp(
  value,
  minimumMasterLimiterReleaseSeconds,
  maximumMasterLimiterReleaseSeconds,
  defaultMasterLimiterReleaseSeconds,
);

double masterLimiterCeilingLinear(double ceilingDb) =>
    math.pow(10, clampMasterLimiterCeilingDb(ceilingDb) / 20).toDouble();

Float32List createMasterLimiterCeilingCurve(
  double ceilingDb, {
  int length = masterLimiterCeilingCurveLength,
}) {
  final safeLength = math.max(2, length);
  final ceiling = masterLimiterCeilingLinear(ceilingDb);
  return Float32List.fromList([
    for (var index = 0; index < safeLength; index++)
      (-1 + (2 * index / (safeLength - 1))).clamp(-ceiling, ceiling),
  ]);
}

String formatMasterLimiterDb(double value) => '${value.toStringAsFixed(1)} dB';

String formatMasterLimiterRelease(double seconds) {
  final clamped = clampMasterLimiterReleaseSeconds(seconds);
  if (clamped >= 1) return '${clamped.toStringAsFixed(2)} s';
  return '${(clamped * 1000).round()} ms';
}

double _finiteClamp(
  double value,
  double minimum,
  double maximum,
  double fallback,
) {
  if (!value.isFinite) return fallback;
  return value.clamp(minimum, maximum).toDouble();
}
