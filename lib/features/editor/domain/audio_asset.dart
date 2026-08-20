class AudioAsset {
  const AudioAsset({
    required this.id,
    required this.name,
    required this.extension,
    required this.size,
    required this.durationSeconds,
    required this.sampleRate,
    required this.numberOfChannels,
    required this.waveformPeaks,
  });

  final String id;
  final String name;
  final String extension;
  final int size;

  final double durationSeconds;
  final double sampleRate;
  final int numberOfChannels;

  /// Sudah di-downsample.
  ///
  /// Nilai 0.0 - 1.0.
  final List<double> waveformPeaks;
}
