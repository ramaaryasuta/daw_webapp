import 'package:daw_webapp/features/editor/application/editor_clipboard.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const audio = AudioAsset(
    id: 'asset-1',
    name: 'source.wav',
    extension: 'wav',
    size: 1024,
    durationSeconds: 12,
    sampleRate: 48000,
    numberOfChannels: 2,
    waveformPeaks: [0.1, 0.6, 0.3],
  );
  const original = AudioClip(
    id: 'clip-1',
    audio: audio,
    timelineStartSeconds: 10,
    sourceStartSeconds: 3,
    clipDurationSeconds: 5,
    gainDb: -5,
    fadeInDurationSeconds: 0.5,
    fadeOutDurationSeconds: 1,
    isReversed: true,
  );

  test('recreates clip metadata with a new placement and shared source', () {
    final copied = CopiedClipData.fromClip(trackId: 'track-1', clip: original);

    final pasted = copied.createClip(id: 'clip-2', timelineStartSeconds: 30);

    expect(pasted.id, 'clip-2');
    expect(pasted.timelineStartSeconds, 30);
    expect(pasted.sourceStartSeconds, 3);
    expect(pasted.clipDurationSeconds, 5);
    expect(pasted.gainDb, -5);
    expect(pasted.fadeInDurationSeconds, 0.5);
    expect(pasted.fadeOutDurationSeconds, 1);
    expect(pasted.isReversed, isTrue);
    expect(identical(pasted.audio, original.audio), isTrue);
    expect(
      identical(pasted.audio.waveformPeaks, original.audio.waveformPeaks),
      isTrue,
    );
  });

  test('clipboard retains one reusable template without a clip ID', () {
    final clipboard = EditorClipClipboard.single(
      CopiedClipData.fromClip(trackId: 'track-1', clip: original),
    );

    expect(clipboard.singleClip, isNotNull);
    expect(clipboard.singleClip!.originalTrackId, 'track-1');
    expect(clipboard.singleClip!.audio.id, 'asset-1');
  });

  test('group clipboard preserves relative offsets and shared sources', () {
    final later = original.copyWith(id: 'clip-2', timelineStartSeconds: 13);
    final clipboard = EditorClipClipboard([
      CopiedClipData.fromClip(
        trackId: 'track-1',
        clip: original,
        timelineOriginSeconds: 10,
      ),
      CopiedClipData.fromClip(
        trackId: 'track-2',
        clip: later,
        timelineOriginSeconds: 10,
      ),
    ]);

    expect(clipboard.clips.map((clip) => clip.timelineOffsetSeconds), [0, 3]);
    expect(clipboard.clips.map((clip) => clip.originalTrackId), [
      'track-1',
      'track-2',
    ]);
    expect(
      clipboard.clips.every((clip) => identical(clip.audio, audio)),
      isTrue,
    );
  });
}
