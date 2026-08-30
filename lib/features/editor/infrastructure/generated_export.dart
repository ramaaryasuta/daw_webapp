import 'dart:typed_data';

import '../domain/daw_track.dart';
import '../domain/export_settings.dart';

class GeneratedExport {
  const GeneratedExport({
    required this.wavBytes,
    required this.durationSeconds,
    required this.sampleRate,
    required this.channelCount,
    required this.fileName,
  }) : bytes = wavBytes,
       format = ExportFormat.wav,
       mimeType = 'audio/wav';

  const GeneratedExport.audio({
    required this.bytes,
    required this.format,
    required this.durationSeconds,
    required this.sampleRate,
    required this.channelCount,
    required this.fileName,
  }) : wavBytes = bytes,
       mimeType = format == ExportFormat.wav ? 'audio/wav' : 'audio/mpeg';

  final Uint8List wavBytes;
  final Uint8List bytes;
  final ExportFormat format;
  final String mimeType;

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

class ExportRenderInfo {
  const ExportRenderInfo({
    required this.durationSeconds,
    required this.sampleRate,
    required this.channelCount,
  });

  final double durationSeconds;
  final int sampleRate;
  final int channelCount;
}

enum ExportGenerationStage { rendering, preparingWav, encodingMp3, metadata }

abstract interface class ExportStudioGenerator {
  ExportRenderInfo describeExport(List<DawTrack> tracks);

  Future<GeneratedExport> generateExport(
    List<DawTrack> tracks,
    ExportSettings settings, {
    void Function(ExportGenerationStage stage)? onStage,
  });
}
