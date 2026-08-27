class StereoPeak {
  const StereoPeak({required this.left, required this.right});

  static const silence = StereoPeak(left: 0, right: 0);

  final double left;
  final double right;
}

class MeterPeaksSnapshot {
  const MeterPeaksSnapshot({required this.tracks, required this.master});

  final Map<String, StereoPeak> tracks;
  final StereoPeak master;
}

abstract interface class AudioMeterPeakSource {
  MeterPeaksSnapshot readMeterPeaks();
}
