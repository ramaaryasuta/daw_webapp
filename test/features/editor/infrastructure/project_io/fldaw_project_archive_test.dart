import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/loop_region.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/domain/timeline_marker.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/fldaw_project_archive.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/fldaw_project_codec.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/project_dto.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = FldawProjectCodec();
  const projectArchive = FldawProjectArchive();

  test('V1 archive round-trips all project fields and deduplicates audio', () {
    final sourceBytes = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);
    final asset = AudioAsset(
      id: 'source-kick',
      name: r'C:\recordings\Kick.wav',
      extension: 'wav',
      size: sourceBytes.length,
      durationSeconds: 4,
      sampleRate: 48000,
      numberOfChannels: 2,
      waveformPeaks: const [0.1, 0.8],
      mimeType: 'audio/wav',
      sourceBytes: sourceBytes,
    );
    final snapshot = FldawProjectSnapshot(
      name: 'My Song',
      bpm: 137.5,
      snapSettings: const SnapSettings(
        enabled: true,
        subdivision: SnapSubdivision.halfBeat,
      ),
      rulerMode: TimelineRulerMode.time,
      isLoopEnabled: true,
      loopRegion: const LoopRegion(startSeconds: 1, endSeconds: 3.5),
      masterVolumeDb: -4.5,
      tracks: [
        DawTrack(
          id: 'track-b',
          name: 'Drums',
          colorValue: 0xff123456,
          volumeDb: -3,
          pan: 0.35,
          isMuted: true,
          isSolo: false,
          clips: [
            AudioClip(
              id: 'clip-a',
              audio: asset,
              timelineStartSeconds: 0.5,
              sourceStartSeconds: 0.25,
              clipDurationSeconds: 1.5,
              gainDb: 2,
              fadeInDurationSeconds: 0.2,
              fadeOutDurationSeconds: 0.3,
            ),
            AudioClip(
              id: 'clip-b',
              audio: asset,
              timelineStartSeconds: 2.25,
              sourceStartSeconds: 1,
              clipDurationSeconds: 2,
              gainDb: -1,
              fadeInDurationSeconds: 0.4,
              fadeOutDurationSeconds: 0.5,
            ),
          ],
        ),
      ],
      markers: const [
        TimelineMarker(
          id: 'marker-9',
          timeSeconds: 2.75,
          name: 'Chorus',
          colorArgb: 0xffabcdef,
        ),
      ],
    );

    final bytes = projectArchive.encode(codec.encodeSnapshot(snapshot));
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(zip.find('project.json'), isNotNull);
    expect(
      zip.files.where((entry) => entry.name.startsWith('audio/')),
      hasLength(1),
    );

    final document = projectArchive.decode(bytes);
    expect(document.manifest.toJson()['format'], 'fldawproj');
    expect(document.manifest.toJson()['formatVersion'], 1);
    expect(document.audioBytesBySourceId, hasLength(1));
    expect(document.audioBytesBySourceId['source-kick'], sourceBytes);
    expect(document.manifest.audioSources.single.originalFilename, 'Kick.wav');

    final restoredAsset = AudioAsset(
      id: asset.id,
      name: document.manifest.audioSources.single.originalFilename,
      extension: asset.extension,
      size: sourceBytes.length,
      durationSeconds: asset.durationSeconds,
      sampleRate: asset.sampleRate,
      numberOfChannels: asset.numberOfChannels,
      waveformPeaks: const [0.2],
      mimeType: asset.mimeType,
      sourceBytes: document.audioBytesBySourceId[asset.id],
    );
    final restored = codec.restore(document.manifest, {
      asset.id: restoredAsset,
    });
    expect(restored.name, 'My Song');
    expect(restored.bpm, 137.5);
    expect(restored.snapSettings.subdivision, SnapSubdivision.halfBeat);
    expect(restored.rulerMode, TimelineRulerMode.time);
    expect(restored.isLoopEnabled, isTrue);
    expect(restored.loopRegion, snapshot.loopRegion);
    expect(restored.masterVolumeDb, -4.5);
    expect(restored.tracks.single.id, 'track-b');
    expect(restored.tracks.single.colorValue, 0xff123456);
    expect(restored.tracks.single.volumeDb, -3);
    expect(restored.tracks.single.pan, 0.35);
    expect(restored.tracks.single.isMuted, isTrue);
    expect(restored.tracks.single.clips.map((clip) => clip.id), [
      'clip-a',
      'clip-b',
    ]);
    expect(restored.tracks.single.clips.last.audio, same(restoredAsset));
    expect(restored.tracks.single.clips.last.sourceStartSeconds, 1);
    expect(restored.tracks.single.clips.last.clipDurationSeconds, 2);
    expect(restored.tracks.single.clips.last.gainDb, -1);
    expect(restored.tracks.single.clips.last.fadeInDurationSeconds, 0.4);
    expect(restored.tracks.single.clips.last.fadeOutDurationSeconds, 0.5);
    expect(restored.markers.single.id, 'marker-9');
  });

  test('archive rejects a newer project version', () {
    final manifest = _emptyManifest()..['formatVersion'] = 2;
    final bytes = _zipWithManifest(manifest);

    expect(
      () => projectArchive.decode(bytes),
      throwsA(
        isA<FldawProjectException>().having(
          (error) => error.userMessage,
          'userMessage',
          contains('newer FLDAW project format'),
        ),
      ),
    );
  });

  test('archive rejects corrupt bytes and ZIPs without project.json', () {
    expect(
      () => projectArchive.decode(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<FldawProjectException>()),
    );
    expect(
      () => projectArchive.decode(
        ZipEncoder().encodeBytes(
          Archive()..add(ArchiveFile.string('notes.txt', 'not a project')),
        ),
      ),
      throwsA(
        isA<FldawProjectException>().having(
          (error) => error.userMessage,
          'userMessage',
          contains('does not contain FLDAW project metadata'),
        ),
      ),
    );
  });

  test('archive rejects missing embedded audio without partial result', () {
    final manifest = _emptyManifest();
    (manifest['audioSources']! as List<Object?>).add({
      'sourceId': 'safe-source',
      'archivePath': 'audio/safe-source.wav',
      'originalFilename': 'safe.wav',
      'extension': 'wav',
      'mimeType': 'audio/wav',
      'size': 4,
      'durationSeconds': 1,
      'sampleRate': 48000,
      'numberOfChannels': 1,
    });

    expect(
      () => projectArchive.decode(_zipWithManifest(manifest)),
      throwsA(
        isA<FldawProjectException>().having(
          (error) => error.userMessage,
          'userMessage',
          contains('audio sources could not be restored'),
        ),
      ),
    );
  });

  test('manifest rejects traversal audio paths', () {
    final manifest = _emptyManifest();
    (manifest['audioSources']! as List<Object?>).add({
      'sourceId': 'unsafe',
      'archivePath': 'audio/../outside.wav',
      'originalFilename': 'source.wav',
      'extension': 'wav',
      'size': 1,
      'durationSeconds': 1,
      'sampleRate': 44100,
      'numberOfChannels': 1,
    });

    expect(
      () => FldawProjectManifest.fromJson(manifest),
      throwsA(isA<FldawProjectException>()),
    );
  });
}

Map<String, Object?> _emptyManifest() => {
  'format': 'fldawproj',
  'formatVersion': 1,
  'project': {
    'name': 'Untitled',
    'bpm': 120,
    'snap': {'enabled': true, 'subdivision': 'quarterBeat'},
    'rulerDisplayMode': 'barsBeats',
    'loop': {'enabled': false},
    'masterVolumeDb': 0,
  },
  'tracks': <Object?>[],
  'clips': <Object?>[],
  'markers': <Object?>[],
  'audioSources': <Object?>[],
};

Uint8List _zipWithManifest(Map<String, Object?> manifest) {
  final archive = Archive()
    ..add(ArchiveFile.string('project.json', jsonEncode(manifest)));
  return ZipEncoder().encodeBytes(archive);
}
