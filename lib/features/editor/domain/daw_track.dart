import 'audio_asset.dart';

class DawTrack {
  const DawTrack({
    required this.id,
    required this.name,
    required this.audio,
    this.startTimeSeconds = 0,
    this.volume = 1,
    this.isMuted = false,
    this.isSolo = false,
  });

  final String id;
  final String name;

  final AudioAsset audio;

  /// Posisi file audio pada project timeline.
  final double startTimeSeconds;

  final double volume;
  final bool isMuted;
  final bool isSolo;

  double get endTimeSeconds => startTimeSeconds + audio.durationSeconds;

  DawTrack copyWith({
    String? id,
    String? name,
    AudioAsset? audio,
    double? startTimeSeconds,
    double? volume,
    bool? isMuted,
    bool? isSolo,
  }) {
    return DawTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      audio: audio ?? this.audio,
      startTimeSeconds: startTimeSeconds ?? this.startTimeSeconds,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }
}
