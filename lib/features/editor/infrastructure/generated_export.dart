import 'dart:typed_data';

import '../domain/daw_track.dart';

class GeneratedExport {
  const GeneratedExport({
    required this.wavBytes,
    required this.durationSeconds,
    required this.sampleRate,
    required this.channelCount,
    required this.fileName,
  });

  final Uint8List wavBytes;

  /// Duration of the rendered audio buffer in fractional seconds.
  final double durationSeconds;

  final int sampleRate;
  final int channelCount;
  final String fileName;
}

typedef RenderedAudioMix = GeneratedExport;

abstract interface class AudioExportGenerator {
  Future<GeneratedExport> generateWavExport(List<DawTrack> tracks);
}
