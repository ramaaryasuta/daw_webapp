import 'dart:typed_data';

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
    this.mimeType,
    this.sourceBytes,
  });

  final String id;
  final String name;
  final String extension;
  final int size;
  final String? mimeType;

  /// Original imported/archived file bytes used for portable project saves.
  ///
  /// This remains ordinary Dart data; decoded Web Audio objects stay owned by
  /// [WebAudioEngine]. Older tests and synthetic assets may omit the bytes, but
  /// a project containing such an asset cannot be packaged.
  final Uint8List? sourceBytes;

  final double durationSeconds;
  final double sampleRate;
  final int numberOfChannels;

  /// Sudah di-downsample.
  ///
  /// Nilai 0.0 - 1.0.
  final List<double> waveformPeaks;
}
