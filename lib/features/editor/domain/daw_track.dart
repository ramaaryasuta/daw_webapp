import 'audio_clip.dart';
import 'track_color.dart';
import 'track_filter_fx.dart';
import 'track_eq_fx.dart';
import 'track_compressor_fx.dart';

const int maximumTrackNameLength = 80;

class DawTrack {
  const DawTrack({
    required this.id,
    required this.name,
    required this.clips,
    int colorValue = TrackColors.purple,
    this.volumeDb = 0,
    double pan = 0,
    this.isMuted = false,
    this.isSolo = false,
    this.filterFx = const TrackFilterFx(),
    this.eqFx = const TrackEqFx(),
    this.compressorFx = const TrackCompressorFx(),
  }) : colorValue = 0xFF000000 | (colorValue & 0x00FFFFFF),
       pan = pan != pan ? 0 : (pan < -1 ? -1 : (pan > 1 ? 1 : pan));

  final String id;
  final String name;
  final int colorValue;

  final List<AudioClip> clips;

  /// Authoritative track fader value in decibels. 0 dB is unity gain.
  final double volumeDb;

  /// Authoritative stereo pan. -1 is hard left, 0 center, and +1 hard right.
  final double pan;
  final bool isMuted;
  final bool isSolo;
  final TrackFilterFx filterFx;
  final TrackEqFx eqFx;
  final TrackCompressorFx compressorFx;

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
    double? pan,
    bool? isMuted,
    bool? isSolo,
    TrackFilterFx? filterFx,
    TrackEqFx? eqFx,
    TrackCompressorFx? compressorFx,
  }) {
    return DawTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clips: clips ?? this.clips,
      colorValue: colorValue ?? this.colorValue,
      volumeDb: volumeDb ?? this.volumeDb,
      pan: pan ?? this.pan,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      filterFx: filterFx ?? this.filterFx,
      eqFx: eqFx ?? this.eqFx,
      compressorFx: compressorFx ?? this.compressorFx,
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
