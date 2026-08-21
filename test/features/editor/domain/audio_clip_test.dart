import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
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
      timelineStartSeconds: 10,
    );

    expect(clip.durationSeconds, 4.5);
    expect(clip.timelineEndSeconds, 14.5);
  });

  test('moving a clip preserves its stable identity and audio asset', () {
    const clip = AudioClip(id: 'clip-1', audio: asset);
    final moved = clip.copyWith(timelineStartSeconds: 12.5);

    expect(moved.id, clip.id);
    expect(moved.audio, same(asset));
    expect(moved.timelineStartSeconds, 12.5);
  });

  test('track end follows its clip timeline position', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clip: AudioClip(id: 'clip-1', audio: asset, timelineStartSeconds: 20),
    );

    expect(track.endTimeSeconds, 24.5);
  });

  test('delays playback while the clip is ahead of the playhead', () {
    const clip = AudioClip(
      id: 'clip-1',
      audio: asset,
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
      timelineStartSeconds: 10,
    );

    final timing = clip.playbackTimingFrom(12.25)!;

    expect(timing.delaySeconds, 0);
    expect(timing.bufferOffsetSeconds, 2.25);
    expect(clip.playbackTimingFrom(14.5), isNull);
  });

  test('project duration is the latest positioned clip end', () {
    final tracks = [
      const DawTrack(
        id: 'track-1',
        name: 'Track 1',
        clip: AudioClip(id: 'clip-1', audio: asset),
      ),
      const DawTrack(
        id: 'track-2',
        name: 'Track 2',
        clip: AudioClip(id: 'clip-2', audio: asset, timelineStartSeconds: 60),
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
        clip: AudioClip(
          id: 'clip-$id',
          audio: trackAsset,
          timelineStartSeconds: start,
        ),
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

  test('effective gain respects volume, mute, and project solo state', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Track 1',
      clip: AudioClip(id: 'clip-1', audio: asset),
      volume: 0.4,
    );

    expect(effectiveTrackGain(track, hasSolo: false), 0.4);
    expect(
      effectiveTrackGain(track.copyWith(isMuted: true), hasSolo: false),
      0,
    );
    expect(effectiveTrackGain(track, hasSolo: true), 0);
    expect(
      effectiveTrackGain(track.copyWith(isSolo: true), hasSolo: true),
      0.4,
    );
  });
}
