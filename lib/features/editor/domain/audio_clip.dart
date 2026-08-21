import 'audio_asset.dart';

/// A placement of an audio asset on the project timeline.
///
/// The timeline position is stored in seconds. Pixel positions are derived by
/// presentation code from the current timeline scale.
class AudioClip {
  const AudioClip({
    required this.id,
    required this.audio,
    this.timelineStartSeconds = 0,
  }) : assert(
         timelineStartSeconds >= 0 && timelineStartSeconds < double.infinity,
       );

  final String id;
  final AudioAsset audio;
  final double timelineStartSeconds;

  double get durationSeconds => audio.durationSeconds;

  double get timelineEndSeconds => timelineStartSeconds + durationSeconds;

  ClipPlaybackTiming? playbackTimingFrom(double timelineSeconds) {
    if (timelineSeconds >= timelineEndSeconds) {
      return null;
    }

    if (timelineSeconds <= timelineStartSeconds) {
      return ClipPlaybackTiming(
        delaySeconds: timelineStartSeconds - timelineSeconds,
        bufferOffsetSeconds: 0,
      );
    }

    return ClipPlaybackTiming(
      delaySeconds: 0,
      bufferOffsetSeconds: timelineSeconds - timelineStartSeconds,
    );
  }

  AudioClip copyWith({
    String? id,
    AudioAsset? audio,
    double? timelineStartSeconds,
  }) {
    return AudioClip(
      id: id ?? this.id,
      audio: audio ?? this.audio,
      timelineStartSeconds: timelineStartSeconds ?? this.timelineStartSeconds,
    );
  }
}

class ClipPlaybackTiming {
  const ClipPlaybackTiming({
    required this.delaySeconds,
    required this.bufferOffsetSeconds,
  });

  /// Delay from the shared Web Audio transport start.
  final double delaySeconds;

  /// Local offset into the clip's decoded audio buffer.
  final double bufferOffsetSeconds;
}
