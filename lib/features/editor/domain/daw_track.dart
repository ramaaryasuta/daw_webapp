import 'audio_clip.dart';
import 'track_color.dart';

const int maximumTrackNameLength = 80;

class DawTrack {
  const DawTrack({
    required this.id,
    required this.name,
    required this.clips,
    int colorValue = TrackColors.purple,
    this.volumeDb = 0,
    this.isMuted = false,
    this.isSolo = false,
  }) : colorValue = 0xFF000000 | (colorValue & 0x00FFFFFF);

  final String id;
  final String name;
  final int colorValue;

  final List<AudioClip> clips;

  /// Authoritative track fader value in decibels. 0 dB is unity gain.
  final double volumeDb;
  final bool isMuted;
  final bool isSolo;

  double get endTimeSeconds {
    var end = 0.0;
    for (final clip in clips) {
      if (clip.timelineEndSeconds > end) {
        end = clip.timelineEndSeconds;
      }
    }
    return end;
  }

  DawTrack copyWith({
    String? id,
    String? name,
    List<AudioClip>? clips,
    int? colorValue,
    double? volumeDb,
    bool? isMuted,
    bool? isSolo,
  }) {
    return DawTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clips: clips ?? this.clips,
      colorValue: colorValue ?? this.colorValue,
      volumeDb: volumeDb ?? this.volumeDb,
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
