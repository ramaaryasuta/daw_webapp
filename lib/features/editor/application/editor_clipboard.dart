import '../domain/audio_asset.dart';
import '../domain/audio_clip.dart';

/// Session-only metadata needed to recreate a clip without copying its source.
class CopiedClipData {
  const CopiedClipData({
    required this.originalTrackId,
    required this.audio,
    this.timelineOffsetSeconds = 0,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.fadeInDurationSeconds,
    required this.fadeOutDurationSeconds,
  });

  factory CopiedClipData.fromClip({
    required String trackId,
    required AudioClip clip,
    double? timelineOriginSeconds,
  }) {
    return CopiedClipData(
      originalTrackId: trackId,
      audio: clip.audio,
      timelineOffsetSeconds:
          clip.timelineStartSeconds -
          (timelineOriginSeconds ?? clip.timelineStartSeconds),
      sourceStartSeconds: clip.sourceStartSeconds,
      clipDurationSeconds: clip.clipDurationSeconds,
      fadeInDurationSeconds: clip.fadeInDurationSeconds,
      fadeOutDurationSeconds: clip.fadeOutDurationSeconds,
    );
  }

  final String originalTrackId;

  /// Shared immutable source reference. PCM, file bytes, and buffers stay owned
  /// by their existing audio-resource layers.
  final AudioAsset audio;
  final double timelineOffsetSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double fadeInDurationSeconds;
  final double fadeOutDurationSeconds;

  AudioClip createClip({
    required String id,
    required double timelineStartSeconds,
  }) {
    return AudioClip(
      id: id,
      audio: audio,
      timelineStartSeconds: timelineStartSeconds,
      sourceStartSeconds: sourceStartSeconds,
      clipDurationSeconds: clipDurationSeconds,
      fadeInDurationSeconds: fadeInDurationSeconds,
      fadeOutDurationSeconds: fadeOutDurationSeconds,
    );
  }
}

/// A list-shaped clipboard so a later multi-clip implementation can extend it.
class EditorClipClipboard {
  EditorClipClipboard(Iterable<CopiedClipData> clips)
    : clips = List<CopiedClipData>.unmodifiable(clips);

  EditorClipClipboard.single(CopiedClipData clip)
    : clips = List.unmodifiable([clip]);

  static final empty = EditorClipClipboard(const []);

  final List<CopiedClipData> clips;

  bool get isEmpty => clips.isEmpty;
  CopiedClipData? get singleClip => clips.length == 1 ? clips.single : null;
}
