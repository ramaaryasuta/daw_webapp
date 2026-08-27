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
    this.fadeInDurationSeconds = 0,
    this.fadeOutDurationSeconds = 0,
  }) : assert(
         timelineStartSeconds >= 0 && timelineStartSeconds < double.infinity,
       ),
       assert(sourceStartSeconds >= 0 && sourceStartSeconds < double.infinity),
       assert(clipDurationSeconds > 0 && clipDurationSeconds < double.infinity),
       assert(fadeInDurationSeconds >= 0),
       assert(fadeOutDurationSeconds >= 0),
       assert(
         fadeInDurationSeconds + fadeOutDurationSeconds <= clipDurationSeconds,
       );

  final String id;
  final AudioAsset audio;
  final double timelineStartSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double fadeInDurationSeconds;
  final double fadeOutDurationSeconds;

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
    double? fadeInDurationSeconds,
    double? fadeOutDurationSeconds,
  }) {
    final duration = clipDurationSeconds ?? this.clipDurationSeconds;
    final fades = clampClipFadeDurations(
      clipDurationSeconds: duration,
      fadeInDurationSeconds:
          fadeInDurationSeconds ?? this.fadeInDurationSeconds,
      fadeOutDurationSeconds:
          fadeOutDurationSeconds ?? this.fadeOutDurationSeconds,
    );
    return AudioClip(
      id: id ?? this.id,
      audio: audio ?? this.audio,
      timelineStartSeconds: timelineStartSeconds ?? this.timelineStartSeconds,
      sourceStartSeconds: sourceStartSeconds ?? this.sourceStartSeconds,
      clipDurationSeconds: duration,
      fadeInDurationSeconds: fades.fadeInDurationSeconds,
      fadeOutDurationSeconds: fades.fadeOutDurationSeconds,
    );
  }
}

class ClipFadeDurations {
  const ClipFadeDurations({
    required this.fadeInDurationSeconds,
    required this.fadeOutDurationSeconds,
  });

  final double fadeInDurationSeconds;
  final double fadeOutDurationSeconds;
}

/// Clamps both fades to the visible clip while preserving their proportion.
ClipFadeDurations clampClipFadeDurations({
  required double clipDurationSeconds,
  required double fadeInDurationSeconds,
  required double fadeOutDurationSeconds,
}) {
  final duration = clipDurationSeconds.isFinite
      ? clipDurationSeconds.clamp(0.0, double.infinity).toDouble()
      : 0.0;
  var fadeIn = fadeInDurationSeconds.isFinite
      ? fadeInDurationSeconds.clamp(0.0, duration).toDouble()
      : 0.0;
  var fadeOut = fadeOutDurationSeconds.isFinite
      ? fadeOutDurationSeconds.clamp(0.0, duration).toDouble()
      : 0.0;
  final total = fadeIn + fadeOut;
  if (total > duration && total > 0) {
    final scale = duration / total;
    fadeIn *= scale;
    fadeOut *= scale;
  }
  return ClipFadeDurations(
    fadeInDurationSeconds: fadeIn,
    fadeOutDurationSeconds: fadeOut,
  );
}

class ClipFadeEnvelopePoint {
  const ClipFadeEnvelopePoint({
    required this.offsetSeconds,
    required this.gain,
  });

  /// Offset from the scheduled source start, not from the clip start.
  final double offsetSeconds;
  final double gain;
}

double clipFadeGainAt(AudioClip clip, double clipLocalSeconds) {
  final local = clipLocalSeconds
      .clamp(0.0, clip.clipDurationSeconds)
      .toDouble();
  if (clip.fadeInDurationSeconds > 0 && local < clip.fadeInDurationSeconds) {
    return local / clip.fadeInDurationSeconds;
  }
  final fadeOutStart = clip.clipDurationSeconds - clip.fadeOutDurationSeconds;
  if (clip.fadeOutDurationSeconds > 0 && local > fadeOutStart) {
    return ((clip.clipDurationSeconds - local) / clip.fadeOutDurationSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }
  return 1;
}

/// Gain automation for a scheduled portion of a clip.
///
/// Both realtime playback and offline export use these points, including when
/// scheduling starts inside a fade after a seek or loop wrap.
List<ClipFadeEnvelopePoint> clipFadeEnvelopeForSegment({
  required AudioClip clip,
  required double clipLocalStartSeconds,
  required double playbackDurationSeconds,
}) {
  final start = clipLocalStartSeconds
      .clamp(0.0, clip.clipDurationSeconds)
      .toDouble();
  final end = (start + playbackDurationSeconds)
      .clamp(start, clip.clipDurationSeconds)
      .toDouble();
  final points = <ClipFadeEnvelopePoint>[
    ClipFadeEnvelopePoint(offsetSeconds: 0, gain: clipFadeGainAt(clip, start)),
  ];

  void addBoundary(double clipLocalSeconds) {
    if (clipLocalSeconds <= start || clipLocalSeconds >= end) {
      return;
    }
    points.add(
      ClipFadeEnvelopePoint(
        offsetSeconds: clipLocalSeconds - start,
        gain: clipFadeGainAt(clip, clipLocalSeconds),
      ),
    );
  }

  addBoundary(clip.fadeInDurationSeconds);
  addBoundary(clip.clipDurationSeconds - clip.fadeOutDurationSeconds);
  if (end > start) {
    points.add(
      ClipFadeEnvelopePoint(
        offsetSeconds: end - start,
        gain: clipFadeGainAt(clip, end),
      ),
    );
  }
  return points;
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
    left: clip.copyWith(
      clipDurationSeconds: leftDuration,
      fadeOutDurationSeconds: 0,
    ),
    right: clip.copyWith(
      id: rightClipId,
      timelineStartSeconds: timelineSeconds,
      sourceStartSeconds: clip.sourceStartSeconds + leftDuration,
      clipDurationSeconds: rightDuration,
      fadeInDurationSeconds: 0,
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
