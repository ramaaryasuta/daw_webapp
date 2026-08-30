import 'dart:typed_data';

import 'package:daw_webapp/features/editor/application/track_duplication.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_eq_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_compressor_fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copy names advance sensibly and avoid generated collisions', () {
    expect(
      nextDuplicateTrackName(
        sourceName: 'Vocals',
        existingNames: const ['Vocals'],
      ),
      'Vocals Copy',
    );
    expect(
      nextDuplicateTrackName(
        sourceName: 'Vocals Copy',
        existingNames: const ['Vocals', 'Vocals Copy', 'Vocals Copy 2'],
      ),
      'Vocals Copy 3',
    );
    expect(
      nextDuplicateTrackName(
        sourceName: List.filled(maximumTrackNameLength, 'A').join(),
        existingNames: const [],
      ).length,
      maximumTrackNameLength,
    );
  });

  test(
    'clone preserves persistent metadata but creates IDs and shares sources',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final peaks = <double>[0.1, 0.7];
      final asset = AudioAsset(
        id: 'source-vocal',
        name: 'vocal.wav',
        extension: 'wav',
        size: bytes.length,
        durationSeconds: 20,
        sampleRate: 48000,
        numberOfChannels: 2,
        waveformPeaks: peaks,
        sourceBytes: bytes,
      );
      final source = DawTrack(
        id: 'track-2',
        name: 'Vocals',
        colorValue: TrackColors.orange,
        volumeDb: -7.5,
        pan: 0.45,
        isMuted: true,
        isSolo: true,
        filterFx: const TrackFilterFx(
          enabled: true,
          highPass: TrackFilterModule(enabled: true, frequencyHz: 180, q: 1.4),
        ),
        eqFx: const TrackEqFx(
          enabled: true,
          lowGainDb: 4,
          midGainDb: -2,
          midFrequencyHz: 1600,
          midQ: 1.8,
          highGainDb: 2.5,
        ),
        compressorFx: const TrackCompressorFx(
          enabled: true,
          thresholdDb: -22,
          ratio: 5,
          attackSeconds: 0.015,
          releaseSeconds: 0.3,
          makeupGainDb: 2,
        ),
        clips: [
          AudioClip(
            id: 'clip-a',
            audio: asset,
            timelineStartSeconds: 3.5,
            sourceStartSeconds: 1.25,
            clipDurationSeconds: 6,
            gainDb: -3,
            fadeInDurationSeconds: 0.5,
            fadeOutDurationSeconds: 1.25,
            isReversed: true,
          ),
          AudioClip(
            id: 'clip-b',
            audio: asset,
            timelineStartSeconds: 8,
            sourceStartSeconds: 4,
            clipDurationSeconds: 5,
            gainDb: 2,
            fadeInDurationSeconds: 1.25,
            fadeOutDurationSeconds: 0.25,
          ),
        ],
      );
      var nextId = 10;

      final duplicate = cloneTrackWithClips(
        source: source,
        newTrackId: 'track-3',
        newName: 'Vocals Copy',
        nextClipId: () => 'clip-${nextId++}',
      );

      expect(duplicate.id, 'track-3');
      expect(duplicate.name, 'Vocals Copy');
      expect(duplicate.colorValue, source.colorValue);
      expect(duplicate.volumeDb, source.volumeDb);
      expect(duplicate.pan, source.pan);
      expect(duplicate.isMuted, source.isMuted);
      expect(duplicate.isSolo, source.isSolo);
      expect(duplicate.filterFx, source.filterFx);
      expect(duplicate.eqFx, source.eqFx);
      expect(duplicate.compressorFx, source.compressorFx);
      expect(duplicate.clips.map((clip) => clip.id), ['clip-10', 'clip-11']);
      expect(duplicate.clips.map((clip) => clip.id).toSet(), hasLength(2));
      for (var index = 0; index < source.clips.length; index++) {
        final originalClip = source.clips[index];
        final copiedClip = duplicate.clips[index];
        expect(identical(copiedClip, originalClip), isFalse);
        expect(identical(copiedClip.audio, originalClip.audio), isTrue);
        expect(identical(copiedClip.audio.waveformPeaks, peaks), isTrue);
        expect(identical(copiedClip.audio.sourceBytes, bytes), isTrue);
        expect(
          copiedClip.timelineStartSeconds,
          originalClip.timelineStartSeconds,
        );
        expect(copiedClip.sourceStartSeconds, originalClip.sourceStartSeconds);
        expect(
          copiedClip.clipDurationSeconds,
          originalClip.clipDurationSeconds,
        );
        expect(copiedClip.gainDb, originalClip.gainDb);
        expect(copiedClip.isReversed, originalClip.isReversed);
        expect(
          copiedClip.fadeInDurationSeconds,
          originalClip.fadeInDurationSeconds,
        );
        expect(
          copiedClip.fadeOutDurationSeconds,
          originalClip.fadeOutDurationSeconds,
        );
      }
      expect(source.id, 'track-2');
      expect(source.clips.map((clip) => clip.id), ['clip-a', 'clip-b']);
    },
  );
}
