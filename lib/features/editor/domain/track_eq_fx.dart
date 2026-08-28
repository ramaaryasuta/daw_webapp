const double minimumEqGainDb = -18;
const double maximumEqGainDb = 18;
const double defaultEqLowFrequencyHz = 120;
const double defaultEqMidFrequencyHz = 1000;
const double defaultEqMidQ = 1;
const double defaultEqHighFrequencyHz = 8000;
const double minimumEqMidFrequencyHz = 200;
const double maximumEqMidFrequencyHz = 5000;
const double minimumEqMidQ = 0.3;
const double maximumEqMidQ = 8;

enum TrackEqParameter { lowGain, midGain, midFrequency, midQ, highGain }

class TrackEqFx {
  const TrackEqFx({
    this.enabled = false,
    this.lowGainDb = 0,
    this.midGainDb = 0,
    this.midFrequencyHz = defaultEqMidFrequencyHz,
    this.midQ = defaultEqMidQ,
    this.highGainDb = 0,
  });

  final bool enabled;
  final double lowGainDb;
  final double midGainDb;
  final double midFrequencyHz;
  final double midQ;
  final double highGainDb;

  bool get isProcessing =>
      enabled && (lowGainDb != 0 || midGainDb != 0 || highGainDb != 0);

  TrackEqFx copyWith({
    bool? enabled,
    double? lowGainDb,
    double? midGainDb,
    double? midFrequencyHz,
    double? midQ,
    double? highGainDb,
  }) {
    return TrackEqFx(
      enabled: enabled ?? this.enabled,
      lowGainDb: clampEqGainDb(lowGainDb ?? this.lowGainDb),
      midGainDb: clampEqGainDb(midGainDb ?? this.midGainDb),
      midFrequencyHz: clampEqMidFrequencyHz(
        midFrequencyHz ?? this.midFrequencyHz,
      ),
      midQ: clampEqMidQ(midQ ?? this.midQ),
      highGainDb: clampEqGainDb(highGainDb ?? this.highGainDb),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackEqFx &&
      enabled == other.enabled &&
      lowGainDb == other.lowGainDb &&
      midGainDb == other.midGainDb &&
      midFrequencyHz == other.midFrequencyHz &&
      midQ == other.midQ &&
      highGainDb == other.highGainDb;

  @override
  int get hashCode => Object.hash(
    enabled,
    lowGainDb,
    midGainDb,
    midFrequencyHz,
    midQ,
    highGainDb,
  );
}

double clampEqGainDb(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(minimumEqGainDb, maximumEqGainDb);
}

double clampEqMidFrequencyHz(double value) {
  if (!value.isFinite) return defaultEqMidFrequencyHz;
  return value.clamp(minimumEqMidFrequencyHz, maximumEqMidFrequencyHz);
}

double clampEqMidQ(double value) {
  if (!value.isFinite) return defaultEqMidQ;
  return value.clamp(minimumEqMidQ, maximumEqMidQ);
}

String formatEqGain(double gainDb) {
  final value = clampEqGainDb(gainDb);
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)} dB';
}

String formatEqFrequency(double frequencyHz) {
  final frequency = clampEqMidFrequencyHz(frequencyHz);
  if (frequency < 1000) return '${frequency.round()} Hz';
  return '${(frequency / 1000).toStringAsFixed(2)} kHz';
}
