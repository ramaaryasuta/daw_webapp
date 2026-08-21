import 'audio_asset.dart';

/// Smallest visible clip region allowed by trim interactions.
const double minimumClipDurationSeconds = 0.01;

/// A placement of an audio asset on the project timeline.
///
/// The timeline position is stored in seconds. Pixel positions are derived by
/// presentation code from the current timeline scale.
class AudioClip {
  const AudioClip({
    required this.id,
    required this.audio,
    required this.clipDurationSeconds,
    this.timelineStartSeconds = 0,
    this.sourceStartSeconds = 0,
  }) : assert(
         timelineStartSeconds >= 0 && timelineStartSeconds < double.infinity,
       ),
       assert(sourceStartSeconds >= 0 && sourceStartSeconds < double.infinity),
       assert(clipDurationSeconds > 0 && clipDurationSeconds < double.infinity);

  final String id;
  final AudioAsset audio;
  final double timelineStartSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;

  double get sourceAudioDurationSeconds => audio.durationSeconds;

  double get sourceEndSeconds => sourceStartSeconds + clipDurationSeconds;

  double get timelineEndSeconds {
    return timelineStartSeconds + clipDurationSeconds;
  }

  ClipPlaybackTiming? playbackTimingFrom(double timelineSeconds) {
    if (timelineSeconds >= timelineEndSeconds) {
      return null;
    }

    if (timelineSeconds <= timelineStartSeconds) {
      return ClipPlaybackTiming(
        delaySeconds: timelineStartSeconds - timelineSeconds,
        bufferOffsetSeconds: sourceStartSeconds,
        playbackDurationSeconds: clipDurationSeconds,
      );
    }

    final clipLocalSeconds = timelineSeconds - timelineStartSeconds;
    return ClipPlaybackTiming(
      delaySeconds: 0,
      bufferOffsetSeconds: sourceStartSeconds + clipLocalSeconds,
      playbackDurationSeconds: clipDurationSeconds - clipLocalSeconds,
    );
  }

  AudioClip copyWith({
    String? id,
    AudioAsset? audio,
    double? timelineStartSeconds,
    double? sourceStartSeconds,
    double? clipDurationSeconds,
  }) {
    return AudioClip(
      id: id ?? this.id,
      audio: audio ?? this.audio,
      timelineStartSeconds: timelineStartSeconds ?? this.timelineStartSeconds,
      sourceStartSeconds: sourceStartSeconds ?? this.sourceStartSeconds,
      clipDurationSeconds: clipDurationSeconds ?? this.clipDurationSeconds,
    );
  }
}

class AudioClipSplit {
  const AudioClipSplit({required this.left, required this.right});

  final AudioClip left;
  final AudioClip right;
}

/// Splits [clip] at an exact timeline time without copying its audio asset.
///
/// Returns `null` when either resulting clip would be shorter than the shared
/// minimum clip duration used by trim interactions.
AudioClipSplit? splitAudioClip({
  required AudioClip clip,
  required String rightClipId,
  required double timelineSeconds,
}) {
  if (!timelineSeconds.isFinite || rightClipId == clip.id) {
    return null;
  }

  final leftDuration = timelineSeconds - clip.timelineStartSeconds;
  final rightDuration = clip.clipDurationSeconds - leftDuration;

  if (leftDuration < minimumClipDurationSeconds ||
      rightDuration < minimumClipDurationSeconds) {
    return null;
  }

  return AudioClipSplit(
    left: clip.copyWith(clipDurationSeconds: leftDuration),
    right: clip.copyWith(
      id: rightClipId,
      timelineStartSeconds: timelineSeconds,
      sourceStartSeconds: clip.sourceStartSeconds + leftDuration,
      clipDurationSeconds: rightDuration,
    ),
  );
}

bool canSplitAudioClip(AudioClip clip, double timelineSeconds) {
  if (!timelineSeconds.isFinite) {
    return false;
  }

  final leftDuration = timelineSeconds - clip.timelineStartSeconds;
  final rightDuration = clip.clipDurationSeconds - leftDuration;
  return leftDuration >= minimumClipDurationSeconds &&
      rightDuration >= minimumClipDurationSeconds;
}

class ClipPlaybackTiming {
  const ClipPlaybackTiming({
    required this.delaySeconds,
    required this.bufferOffsetSeconds,
    required this.playbackDurationSeconds,
  });

  /// Delay from the shared Web Audio transport start.
  final double delaySeconds;

  /// Local offset into the clip's decoded audio buffer.
  final double bufferOffsetSeconds;

  /// Remaining visible clip duration from the scheduled start point.
  final double playbackDurationSeconds;
}
