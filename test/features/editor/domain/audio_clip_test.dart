import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_mixer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const asset = AudioAsset(
    id: 'asset-1',
    name: 'clip.wav',
    extension: 'wav',
    size: 1024,
    durationSeconds: 4.5,
    sampleRate: 48000,
    numberOfChannels: 2,
    waveformPeaks: [0.25, 0.75],
  );

  test('stores timeline position in seconds and derives its end', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      clipDurationSeconds: 4.5,
      timelineStartSeconds: 10,
    );

    expect(clip.sourceAudioDurationSeconds, 4.5);
    expect(clip.clipDurationSeconds, 4.5);
    expect(clip.timelineEndSeconds, 14.5);
  });

  test('moving a clip preserves its stable identity and audio asset', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      clipDurationSeconds: 4.5,
    );
    final moved = clip.copyWith(timelineStartSeconds: 12.5);

    expect(moved.id, clip.id);
    expect(moved.audio, same(asset));
    expect(moved.timelineStartSeconds, 12.5);
  });

  test('track end follows its clip timeline position', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clips: [
        AudioClip(
          id: 'clip-1',
          audio: asset,
          clipDurationSeconds: 4.5,
          timelineStartSeconds: 20,
        ),
      ],
    );

    expect(track.endTimeSeconds, 24.5);
  });

  test('delays playback while the clip is ahead of the playhead', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      clipDurationSeconds: 4.5,
      timelineStartSeconds: 10,
    );

    final timing = clip.playbackTimingFrom(3)!;

    expect(timing.delaySeconds, 7);
    expect(timing.bufferOffsetSeconds, 0);
  });

  test('uses a local buffer offset when seeking into a moved clip', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      clipDurationSeconds: 4.5,
      timelineStartSeconds: 10,
    );

    final timing = clip.playbackTimingFrom(12.25)!;

    expect(timing.delaySeconds, 0);
    expect(timing.bufferOffsetSeconds, 2.25);
    expect(timing.playbackDurationSeconds, 2.25);
    expect(clip.playbackTimingFrom(14.5), isNull);
  });

  test('trimmed clip keeps source range separate from timeline placement', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: 10,
      sourceStartSeconds: 1,
      clipDurationSeconds: 2.5,
    );

    expect(clip.sourceAudioDurationSeconds, 4.5);
    expect(clip.sourceEndSeconds, 3.5);
    expect(clip.timelineEndSeconds, 12.5);
  });

  test('playback and seek respect a trimmed source range', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: 10,
      sourceStartSeconds: 1,
      clipDurationSeconds: 2.5,
    );

    final beforeClip = clip.playbackTimingFrom(8)!;
    expect(beforeClip.delaySeconds, 2);
    expect(beforeClip.bufferOffsetSeconds, 1);
    expect(beforeClip.playbackDurationSeconds, 2.5);

    final insideClip = clip.playbackTimingFrom(11.5)!;
    expect(insideClip.delaySeconds, 0);
    expect(insideClip.bufferOffsetSeconds, 2.5);
    expect(insideClip.playbackDurationSeconds, 1);
    expect(clip.playbackTimingFrom(12.5), isNull);
  });

  test('moving a trimmed clip preserves its source range', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      sourceStartSeconds: 1,
      clipDurationSeconds: 2,
    );

    final moved = clip.copyWith(timelineStartSeconds: 20);

    expect(moved.timelineStartSeconds, 20);
    expect(moved.sourceStartSeconds, 1);
    expect(moved.clipDurationSeconds, 2);
  });

  test('splits a trimmed clip into two shared-source timeline ranges', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: 10,
      sourceStartSeconds: 1,
      clipDurationSeconds: 3,
    );

    final split = splitAudioClip(
      clip: clip,
      rightClipId: 'clip-2',
      timelineSeconds: 11.25,
    )!;

    expect(split.left.id, 'clip-1');
    expect(split.right.id, 'clip-2');
    expect(split.left.audio, same(asset));
    expect(split.right.audio, same(asset));
    expect(split.left.timelineStartSeconds, 10);
    expect(split.left.sourceStartSeconds, 1);
    expect(split.left.clipDurationSeconds, 1.25);
    expect(split.right.timelineStartSeconds, 11.25);
    expect(split.right.sourceStartSeconds, 2.25);
    expect(split.right.clipDurationSeconds, 1.75);
    expect(split.left.timelineEndSeconds, split.right.timelineStartSeconds);
    expect(split.left.sourceEndSeconds, split.right.sourceStartSeconds);
    expect(split.right.timelineEndSeconds, clip.timelineEndSeconds);
    expect(split.right.sourceEndSeconds, clip.sourceEndSeconds);
  });

  test('rejects splits at or within the minimum duration from an edge', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: 10,
      clipDurationSeconds: 3,
    );

    expect(canSplitAudioClip(clip, 10), isFalse);
    expect(canSplitAudioClip(clip, 13), isFalse);
    expect(
      canSplitAudioClip(clip, 10 + minimumClipDurationSeconds / 2),
      isFalse,
    );
    expect(
      canSplitAudioClip(clip, 13 - minimumClipDurationSeconds / 2),
      isFalse,
    );
    expect(canSplitAudioClip(clip, 11), isTrue);
  });

  test('project duration uses the visible trimmed clip end', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clips: [
        AudioClip(
          id: 'clip-1',
          audio: asset,
          timelineStartSeconds: 20,
          sourceStartSeconds: 1,
          clipDurationSeconds: 2,
        ),
      ],
    );

    expect(calculateProjectDurationSeconds([track]), 22);
  });

  test('project duration uses the latest clip on a multi-clip track', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clips: [
        AudioClip(
          id: 'clip-1',
          audio: asset,
          timelineStartSeconds: 2,
          clipDurationSeconds: 1,
        ),
        AudioClip(
          id: 'clip-2',
          audio: asset,
          timelineStartSeconds: 8,
          sourceStartSeconds: 1,
          clipDurationSeconds: 2,
        ),
      ],
    );

    expect(calculateProjectDurationSeconds([track]), 10);
  });

  test('project duration is the latest positioned clip end', () {
    final tracks = [
      const DawTrack(
        id: 'track-1',
        name: 'Track 1',
        clips: [
          AudioClip(id: 'clip-1', audio: asset, clipDurationSeconds: 4.5),
        ],
      ),
      const DawTrack(
        id: 'track-2',
        name: 'Track 2',
        clips: [
          AudioClip(
            id: 'clip-2',
            audio: asset,
            clipDurationSeconds: 4.5,
            timelineStartSeconds: 60,
          ),
        ],
      ),
    ];

    expect(calculateProjectDurationSeconds(tracks), 64.5);
  });

  group('export arrangement duration', () {
    DawTrack track(String id, double start, double duration) {
      final trackAsset = AudioAsset(
        id: 'asset-$id',
        name: '$id.wav',
        extension: 'wav',
        size: 1024,
        durationSeconds: duration,
        sampleRate: 48000,
        numberOfChannels: 2,
        waveformPeaks: const [0.25, 0.75],
      );

      return DawTrack(
        id: 'track-$id',
        name: 'Track $id',
        clips: [
          AudioClip(
            id: 'clip-$id',
            audio: trackAsset,
            clipDurationSeconds: duration,
            timelineStartSeconds: start,
          ),
        ],
      );
    }

    test('one five-second clip at zero ends at five seconds', () {
      expect(calculateProjectDurationSeconds([track('a', 0, 5)]), 5);
    });

    test('a moved clip includes leading silence', () {
      expect(calculateProjectDurationSeconds([track('a', 10, 5)]), 15);
    });

    test('separated clips include silence between them', () {
      expect(
        calculateProjectDurationSeconds([track('a', 0, 5), track('b', 10, 3)]),
        13,
      );
    });

    test('overlapping clips use their latest end instead of their sum', () {
      expect(
        calculateProjectDurationSeconds([track('a', 0, 10), track('b', 5, 3)]),
        10,
      );
    });

    test('sub-second clips retain fractional precision', () {
      expect(calculateProjectDurationSeconds([track('a', 0, 0.75)]), 0.75);
    });
  });

  test('dB conversion and effective gain share DAW mixer semantics', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clips: [AudioClip(id: 'clip-1', audio: asset, clipDurationSeconds: 4.5)],
      volumeDb: -6,
    );

    expect(dbToLinearGain(0), 1);
    expect(dbToLinearGain(-6), closeTo(0.501187, 0.000001));
    expect(dbToLinearGain(6), closeTo(1.995262, 0.000001));
    expect(
      effectiveTrackGain(track, hasSolo: false),
      closeTo(0.501187, 0.000001),
    );
    expect(
      effectiveTrackGain(track.copyWith(isMuted: true), hasSolo: false),
      0,
    );
    expect(effectiveTrackGain(track, hasSolo: true), 0);
    expect(
      effectiveTrackGain(track.copyWith(isSolo: true), hasSolo: true),
      closeTo(0.501187, 0.000001),
    );
    expect(
      effectiveTrackGain(
        track.copyWith(isSolo: true, isMuted: true),
        hasSolo: true,
      ),
      0,
    );
    expect(formatTrackVolumeDb(3), '+3.0 dB');
    expect(formatTrackVolumeDb(-8.42), '-8.4 dB');
  });
}
