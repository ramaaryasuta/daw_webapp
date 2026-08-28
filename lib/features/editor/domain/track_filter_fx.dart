const double minimumFilterFrequencyHz = 20;
const double maximumFilterFrequencyHz = 20000;
const double minimumFilterQ = 0.1;
const double maximumFilterQ = 18;
const double defaultHighPassFrequencyHz = 80;
const double defaultLowPassFrequencyHz = 16000;
const double defaultFilterQ = 0.71;

enum TrackFilterParameter {
  highPassFrequency,
  highPassQ,
  lowPassFrequency,
  lowPassQ,
}

class TrackFilterModule {
  const TrackFilterModule({
    this.enabled = false,
    required this.frequencyHz,
    this.q = defaultFilterQ,
  });

  final bool enabled;
  final double frequencyHz;
  final double q;

  TrackFilterModule copyWith({bool? enabled, double? frequencyHz, double? q}) {
    return TrackFilterModule(
      enabled: enabled ?? this.enabled,
      frequencyHz: clampFilterFrequencyHz(frequencyHz ?? this.frequencyHz),
      q: clampFilterQ(q ?? this.q),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackFilterModule &&
      enabled == other.enabled &&
      frequencyHz == other.frequencyHz &&
      q == other.q;

  @override
  int get hashCode => Object.hash(enabled, frequencyHz, q);
}

class TrackFilterFx {
  const TrackFilterFx({
    this.enabled = false,
    this.highPass = const TrackFilterModule(
      frequencyHz: defaultHighPassFrequencyHz,
    ),
    this.lowPass = const TrackFilterModule(
      frequencyHz: defaultLowPassFrequencyHz,
    ),
  });

  final bool enabled;
  final TrackFilterModule highPass;
  final TrackFilterModule lowPass;

  bool get isProcessing => enabled && (highPass.enabled || lowPass.enabled);

  TrackFilterFx copyWith({
    bool? enabled,
    TrackFilterModule? highPass,
    TrackFilterModule? lowPass,
  }) {
    return TrackFilterFx(
      enabled: enabled ?? this.enabled,
      highPass: highPass ?? this.highPass,
      lowPass: lowPass ?? this.lowPass,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackFilterFx &&
      enabled == other.enabled &&
      highPass == other.highPass &&
      lowPass == other.lowPass;

  @override
  int get hashCode => Object.hash(enabled, highPass, lowPass);
}

double clampFilterFrequencyHz(double value) {
  if (!value.isFinite) {
    return minimumFilterFrequencyHz;
  }
  return value.clamp(minimumFilterFrequencyHz, maximumFilterFrequencyHz);
}

double clampFilterQ(double value) {
  if (!value.isFinite) {
    return defaultFilterQ;
  }
  return value.clamp(minimumFilterQ, maximumFilterQ);
}

String formatFilterFrequency(double frequencyHz) {
  final clamped = clampFilterFrequencyHz(frequencyHz);
  if (clamped < 1000) {
    return '${clamped.round()} Hz';
  }
  final kilohertz = clamped / 1000;
  final decimals = kilohertz >= 10 ? 1 : 2;
  var value = kilohertz.toStringAsFixed(decimals);
  value = value.replaceFirst(RegExp(r'\.0+$'), '');
  value = value.replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
  return '$value kHz';
}
