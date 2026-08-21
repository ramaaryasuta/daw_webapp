import 'audio_clip.dart';

class DawTrack {
  const DawTrack({
    required this.id,
    required this.name,
    required this.clip,
    this.volume = 1,
    this.isMuted = false,
    this.isSolo = false,
  });

  final String id;
  final String name;

  final AudioClip clip;

  final double volume;
  final bool isMuted;
  final bool isSolo;

  double get endTimeSeconds => clip.timelineEndSeconds;

  DawTrack copyWith({
    String? id,
    String? name,
    AudioClip? clip,
    double? volume,
    bool? isMuted,
    bool? isSolo,
  }) {
    return DawTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clip: clip ?? this.clip,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }
}

double calculateProjectDurationSeconds(Iterable<DawTrack> tracks) {
  var duration = 0.0;

  for (final track in tracks) {
    if (track.endTimeSeconds > duration) {
      duration = track.endTimeSeconds;
    }
  }

  return duration;
}

double effectiveTrackGain(DawTrack track, {required bool hasSolo}) {
  if (track.isMuted || (hasSolo && !track.isSolo)) {
    return 0;
  }

  return track.volume;
}
