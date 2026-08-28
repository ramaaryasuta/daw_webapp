@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/imported_audio_file.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/fldaw_project_codec.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/project_autosave_store.dart';
import 'package:daw_webapp/features/editor/infrastructure/wav_encoder.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Save, Open, then import and edit keeps every identity independent',
    () async {
      final bytes = _toneWav();
      final document = _oldCounterIdDocument(bytes);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);

      await controller.openProjectDocument(document);
      var state = container.read(editorControllerProvider);
      expect(_allClips(state).map((clip) => clip.id), ['clip-1', 'clip-2']);
      expect(_allClips(state).map((clip) => clip.audio.id), [
        'source-1',
        'source-2',
      ]);

      final addedTrackId = controller.addTrack();
      expect(addedTrackId, startsWith('track-'));
      expect(addedTrackId, isNot(anyOf('track-1', 'track-2')));
      final failures = await controller.importAudioFiles([
        _imported('audioC.wav', bytes),
        _imported('audioD.wav', bytes),
      ]);
      expect(failures, isEmpty);

      state = container.read(editorControllerProvider);
      final clipA = _clipNamed(state, 'audioA.wav');
      final clipB = _clipNamed(state, 'audioB.wav');
      final clipC = _clipNamed(state, 'audioC.wav');
      final clipD = _clipNamed(state, 'audioD.wav');
      _expectUniqueProjectIds(state);
      expect({clipA.id, clipB.id, clipC.id, clipD.id}, hasLength(4));
      expect({
        clipA.audio.id,
        clipB.audio.id,
        clipC.audio.id,
        clipD.audio.id,
      }, hasLength(4));

      final originalA = clipA;
      final originalATrackId = _trackContaining(state, clipA.id).id;
      controller.selectClip(
        trackId: _trackContaining(state, clipC.id).id,
        clipId: clipC.id,
      );
      expect(container.read(editorControllerProvider).selectedClipIds, {
        clipC.id,
      });

      await controller.moveClip(clipC.id, 0.2, trackDelta: -1);
      state = container.read(editorControllerProvider);
      expect(
        _clipById(state, clipA.id).timelineStartSeconds,
        originalA.timelineStartSeconds,
      );
      expect(_trackContaining(state, clipA.id).id, originalATrackId);
      expect(
        _clipById(state, clipC.id).timelineStartSeconds,
        closeTo(0.2, 0.000001),
      );

      await controller.updateClipTrim(
        clipId: clipC.id,
        timelineStartSeconds: 0.25,
        sourceStartSeconds: 0.01,
        clipDurationSeconds: 0.08,
      );
      state = container.read(editorControllerProvider);
      expect(
        _clipById(state, clipA.id).clipDurationSeconds,
        originalA.clipDurationSeconds,
      );
      expect(
        _clipById(state, clipC.id).clipDurationSeconds,
        closeTo(0.08, 0.000001),
      );

      await controller.splitClip(clipC.id, 0.29);
      state = container.read(editorControllerProvider);
      final cSourceId = _clipById(state, clipC.id).audio.id;
      final cSourceClips = _allClips(
        state,
      ).where((clip) => clip.audio.id == cSourceId).toList();
      expect(cSourceClips, hasLength(2));
      expect(cSourceClips.map((clip) => clip.id).toSet(), hasLength(2));
      expect(
        _clipById(state, clipA.id).clipDurationSeconds,
        originalA.clipDurationSeconds,
      );

      controller.selectClip(
        trackId: _trackContaining(state, clipD.id).id,
        clipId: clipD.id,
      );
      controller.copySelectedClip();
      await controller.pasteCopiedClip();
      final pasteOneId = container
          .read(editorControllerProvider)
          .selectedClipId!;
      await controller.pasteCopiedClip();
      final pasteTwoId = container
          .read(editorControllerProvider)
          .selectedClipId!;
      expect({clipD.id, pasteOneId, pasteTwoId}, hasLength(3));
      expect(
        _clipById(
          container.read(editorControllerProvider),
          pasteOneId,
        ).audio.id,
        clipD.audio.id,
      );

      await controller.duplicateSelectedClip();
      final duplicatedClipId = container
          .read(editorControllerProvider)
          .selectedClipId!;
      expect({
        clipD.id,
        pasteOneId,
        pasteTwoId,
        duplicatedClipId,
      }, hasLength(4));
      expect(
        _clipById(
          container.read(editorControllerProvider),
          duplicatedClipId,
        ).audio.id,
        clipD.audio.id,
      );

      final dTrackId = _trackContaining(
        container.read(editorControllerProvider),
        clipD.id,
      ).id;
      final duplicatedTrackId = await controller.duplicateTrack(dTrackId);
      expect(duplicatedTrackId, isNotNull);
      state = container.read(editorControllerProvider);
      final duplicatedTrack = state.tracks.singleWhere(
        (track) => track.id == duplicatedTrackId,
      );
      final duplicatedTrackClipIds = duplicatedTrack.clips
          .map((clip) => clip.id)
          .toList();
      expect(
        duplicatedTrackClipIds.toSet(),
        hasLength(duplicatedTrackClipIds.length),
      );
      expect(
        duplicatedTrackClipIds.toSet().intersection(
          _allClips(state)
              .where((clip) => !duplicatedTrackClipIds.contains(clip.id))
              .map((clip) => clip.id)
              .toSet(),
        ),
        isEmpty,
      );
      expect(duplicatedTrack.clips.map((clip) => clip.audio.id).toSet(), {
        clipD.audio.id,
      });

      await controller.undo();
      expect(
        container
            .read(editorControllerProvider)
            .tracks
            .any((track) => track.id == duplicatedTrackId),
        isFalse,
      );
      await controller.redo();
      state = container.read(editorControllerProvider);
      final redoneTrack = state.tracks.singleWhere(
        (track) => track.id == duplicatedTrackId,
      );
      expect(redoneTrack.clips.map((clip) => clip.id), duplicatedTrackClipIds);

      final markerId = controller.addMarker(0.1);
      final sectionId = controller.addSection(0.1, 0.3);
      expect(markerId, startsWith('marker-'));
      expect(sectionId, startsWith('section-'));
      state = container.read(editorControllerProvider);
      _expectUniqueProjectIds(state);

      // Save performs the same complete integrity validation as Open/Recovery.
      const FldawProjectCodec().encodeSnapshot(_snapshotFromState(state));
    },
  );

  test(
    'IndexedDB Recovery into a fresh controller cannot reuse loaded IDs',
    () async {
      final bytes = _toneWav();
      final firstContainer = ProviderContainer();
      final firstStore = firstContainer.read(projectAutosaveStoreProvider);
      await firstStore.discardRecovery();
      await firstStore.saveDocument(_oldCounterIdDocument(bytes));
      firstContainer.dispose();

      final recoveredContainer = ProviderContainer();
      addTearDown(recoveredContainer.dispose);
      final store = recoveredContainer.read(projectAutosaveStoreProvider);
      addTearDown(store.discardRecovery);
      final recovery = await store.readRecovery();
      expect(recovery, isNotNull);
      final recoveredDocument = await store.loadDocument(recovery!);
      final controller = recoveredContainer.read(
        editorControllerProvider.notifier,
      );
      await controller.openProjectDocument(
        recoveredDocument,
        recoveredAutosave: true,
      );
      await controller.importAudioFiles([_imported('audioC.wav', bytes)]);

      final state = recoveredContainer.read(editorControllerProvider);
      expect(_allClips(state).map((clip) => clip.id).toSet(), hasLength(3));
      expect(
        _allClips(state).map((clip) => clip.audio.id).toSet(),
        hasLength(3),
      );
      expect(_clipNamed(state, 'audioA.wav').id, 'clip-1');
      expect(_clipNamed(state, 'audioB.wav').id, 'clip-2');
      expect(
        _clipNamed(state, 'audioC.wav').id,
        isNot(anyOf('clip-1', 'clip-2')),
      );
    },
  );
}

FldawProjectDocument _oldCounterIdDocument(Uint8List bytes) {
  AudioAsset source(String id, String name) => AudioAsset(
    id: id,
    name: name,
    extension: 'wav',
    size: bytes.length,
    durationSeconds: 0.2,
    sampleRate: 48000,
    numberOfChannels: 1,
    waveformPeaks: const [0.1],
    mimeType: 'audio/wav',
    sourceBytes: bytes,
  );
  final sourceA = source('source-1', 'audioA.wav');
  final sourceB = source('source-2', 'audioB.wav');
  return const FldawProjectCodec().encodeSnapshot(
    FldawProjectSnapshot(
      name: 'Identity Regression',
      bpm: 120,
      snapSettings: const SnapSettings(),
      rulerMode: TimelineRulerMode.barsBeats,
      isLoopEnabled: false,
      loopRegion: null,
      masterVolumeDb: 0,
      tracks: [
        DawTrack(
          id: 'track-1',
          name: 'Track A',
          clips: [
            AudioClip(id: 'clip-1', audio: sourceA, clipDurationSeconds: 0.1),
          ],
        ),
        DawTrack(
          id: 'track-2',
          name: 'Track B',
          clips: [
            AudioClip(id: 'clip-2', audio: sourceB, clipDurationSeconds: 0.1),
          ],
        ),
      ],
      markers: const [],
    ),
  );
}

FldawProjectSnapshot _snapshotFromState(EditorState state) =>
    FldawProjectSnapshot(
      name: state.projectName,
      bpm: 120,
      snapSettings: const SnapSettings(),
      rulerMode: TimelineRulerMode.barsBeats,
      isLoopEnabled: state.isLoopEnabled,
      loopRegion: state.loopRegion,
      masterVolumeDb: state.masterVolumeDb,
      tracks: state.tracks,
      markers: state.markers,
      sections: state.sections,
    );

ImportedAudioFile _imported(String name, Uint8List bytes) => ImportedAudioFile(
  name: name,
  extension: 'wav',
  bytes: bytes,
  size: bytes.length,
  mimeType: 'audio/wav',
);

Uint8List _toneWav() {
  final samples = Float32List(9600)..fillRange(0, 9600, 0.1);
  return WavEncoder.encodePcm16(channels: [samples], sampleRate: 48000);
}

List<AudioClip> _allClips(EditorState state) => [
  for (final track in state.tracks) ...track.clips,
];

AudioClip _clipNamed(EditorState state, String name) =>
    _allClips(state).singleWhere((clip) => clip.audio.name == name);

AudioClip _clipById(EditorState state, String id) =>
    _allClips(state).singleWhere((clip) => clip.id == id);

DawTrack _trackContaining(EditorState state, String clipId) => state.tracks
    .singleWhere((track) => track.clips.any((clip) => clip.id == clipId));

void _expectUniqueProjectIds(EditorState state) {
  expect(
    state.tracks.map((track) => track.id).toSet(),
    hasLength(state.tracks.length),
  );
  final clips = _allClips(state);
  expect(clips.map((clip) => clip.id).toSet(), hasLength(clips.length));
  expect(
    state.markers.map((marker) => marker.id).toSet(),
    hasLength(state.markers.length),
  );
  expect(
    state.sections.map((section) => section.id).toSet(),
    hasLength(state.sections.length),
  );
}
