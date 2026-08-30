import 'package:daw_webapp/features/editor/application/editor_history.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_compressor_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_delay_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_fx_chain.dart';
import 'package:daw_webapp/features/editor/domain/track_reverb_fx.dart';
import 'package:daw_webapp/features/editor/domain/timeline_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final waveform = <double>[0.1, 0.5, 0.2];
  final asset = AudioAsset(
    id: 'asset-1',
    name: 'audio.wav',
    extension: 'wav',
    size: 1024,
    durationSeconds: 20,
    sampleRate: 48000,
    numberOfChannels: 2,
    waveformPeaks: waveform,
  );

  test('Filter FX metadata participates in project history', () {
    const track = DawTrack(id: 'track-1', name: 'Vocals', clips: []);
    final before = ProjectSnapshot(
      tracks: const [track],
      bpm: 120,
      selectedTrackId: track.id,
    );
    final after = ProjectSnapshot(
      tracks: [
        track.copyWith(
          filterFx: const TrackFilterFx(
            enabled: true,
            highPass: TrackFilterModule(
              enabled: true,
              frequencyHz: 240,
              q: 1.25,
            ),
          ),
        ),
      ],
      bpm: 120,
      selectedTrackId: track.id,
    );

    final history = EditorHistory().record(
      label: 'Change HP Cutoff',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Change HP Cutoff');
    expect(
      history.undo(after)!.snapshot.tracks.single.filterFx.enabled,
      isFalse,
    );
  });

  test('Compressor metadata participates in project history', () {
    const track = DawTrack(id: 'track-1', name: 'Vocals', clips: []);
    final before = ProjectSnapshot(
      tracks: const [track],
      bpm: 120,
      selectedTrackId: track.id,
    );
    final after = ProjectSnapshot(
      tracks: [
        track.copyWith(
          compressorFx: const TrackCompressorFx(
            enabled: true,
            thresholdDb: -30,
            ratio: 8,
          ),
        ),
      ],
      bpm: 120,
      selectedTrackId: track.id,
    );

    final history = EditorHistory().record(
      label: 'Change Compressor Threshold',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Change Compressor Threshold');
    expect(
      history.undo(after)!.snapshot.tracks.single.compressorFx,
      const TrackCompressorFx(),
    );
  });

  test('Track FX order participates in project history', () {
    const track = DawTrack(id: 'track-1', name: 'Vocals', clips: []);
    final before = ProjectSnapshot(
      tracks: const [track],
      bpm: 120,
      selectedTrackId: track.id,
    );
    final after = ProjectSnapshot(
      tracks: [
        track.copyWith(
          fxChainOrder: const [
            TrackFxType.compressor,
            TrackFxType.delay,
            TrackFxType.eq,
            TrackFxType.filter,
            TrackFxType.reverb,
          ],
        ),
      ],
      bpm: 120,
      selectedTrackId: track.id,
    );

    final history = EditorHistory().record(
      label: 'Reorder Track FX',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Reorder Track FX');
    expect(
      history.undo(after)!.snapshot.tracks.single.fxChainOrder,
      defaultTrackFxChainOrder,
    );
  });

  test('Delay metadata participates in project history', () {
    const track = DawTrack(id: 'track-1', name: 'Vocals', clips: []);
    final before = ProjectSnapshot(
      tracks: const [track],
      bpm: 120,
      selectedTrackId: track.id,
    );
    final after = ProjectSnapshot(
      tracks: [
        track.copyWith(
          delayFx: const TrackDelayFx(
            enabled: true,
            syncToBpm: true,
            syncDivision: DelaySyncDivision.dottedQuarter,
            feedback: 0.7,
            mix: 0.45,
          ),
        ),
      ],
      bpm: 120,
      selectedTrackId: track.id,
    );

    final history = EditorHistory().record(
      label: 'Change Delay Feedback',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Change Delay Feedback');
    expect(
      history.undo(after)!.snapshot.tracks.single.delayFx,
      const TrackDelayFx(),
    );
  });

  test('Reverb metadata participates in project history', () {
    const track = DawTrack(id: 'track-1', name: 'Vocals', clips: []);
    final before = ProjectSnapshot(
      tracks: const [track],
      bpm: 120,
      selectedTrackId: track.id,
    );
    final after = ProjectSnapshot(
      tracks: [
        track.copyWith(
          reverbFx: const TrackReverbFx(
            enabled: true,
            preDelaySeconds: 0.08,
            decaySeconds: 4.5,
            dampingHz: 4200,
            mix: 0.4,
          ),
        ),
      ],
      bpm: 120,
      selectedTrackId: track.id,
    );

    final history = EditorHistory().record(
      label: 'Change Reverb Decay',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Change Reverb Decay');
    expect(
      history.undo(after)!.snapshot.tracks.single.reverbFx,
      const TrackReverbFx(),
    );
  });

  test('marker project state records metadata in history', () {
    const marker = TimelineMarker(
      id: 'marker-1',
      timeSeconds: 8,
      name: 'Verse',
      colorArgb: TrackColors.blue,
    );
    final before = ProjectSnapshot(
      tracks: const [],
      markers: const [marker],
      bpm: 120,
      selectedTrackId: null,
    );
    final after = ProjectSnapshot(
      tracks: const [],
      markers: [marker.copyWith(name: 'Chorus')],
      bpm: 120,
      selectedTrackId: null,
    );

    final history = EditorHistory().record(
      label: 'Rename Marker',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Rename Marker');
    expect(history.undo(after)!.snapshot.markers.single, same(marker));
  });

  test('time signature is persistent undoable project state', () {
    final before = ProjectSnapshot(
      tracks: const [],
      bpm: 120,
      selectedTrackId: null,
    );
    final after = ProjectSnapshot(
      tracks: const [],
      bpm: 120,
      timeSignature: TimeSignature.threeFour,
      selectedTrackId: null,
    );

    final history = EditorHistory().record(
      label: 'Change Time Signature',
      before: before,
      after: after,
    );

    expect(history.past.single.label, 'Change Time Signature');
    expect(
      history.undo(after)!.snapshot.timeSignature,
      TimeSignature.commonTime,
    );
  });

  ProjectSnapshot snapshot({
    required double start,
    double sourceStart = 0,
    double duration = 10,
    double bpm = 120,
    double masterVolumeDb = 0,
    bool split = false,
    String trackName = 'Track',
    int trackColorValue = TrackColors.purple,
    double volumeDb = 0,
    double pan = 0,
    bool isMuted = false,
    bool isSolo = false,
    double gainDb = 0,
    double fadeIn = 0,
    double fadeOut = 0,
    bool isReversed = false,
  }) {
    final original = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: start,
      sourceStartSeconds: sourceStart,
      clipDurationSeconds: duration,
      gainDb: gainDb,
      fadeInDurationSeconds: fadeIn,
      fadeOutDurationSeconds: fadeOut,
      isReversed: isReversed,
    );
    return ProjectSnapshot(
      tracks: [
        DawTrack(
          id: 'track-1',
          name: trackName,
          colorValue: trackColorValue,
          volumeDb: volumeDb,
          pan: pan,
          isMuted: isMuted,
          isSolo: isSolo,
          clips: split
              ? [
                  original.copyWith(clipDurationSeconds: duration / 2),
                  original.copyWith(
                    id: 'clip-2',
                    timelineStartSeconds: start + duration / 2,
                    sourceStartSeconds: sourceStart + duration / 2,
                    clipDurationSeconds: duration / 2,
                  ),
                ]
              : [original],
        ),
      ],
      bpm: bpm,
      masterVolumeDb: masterVolumeDb,
      selectedTrackId: 'track-1',
      selectedClipId: split ? 'clip-2' : 'clip-1',
    );
  }

  test('records clip reverse as persistent project state', () {
    final normal = snapshot(start: 0);
    final reversed = snapshot(start: 0, isReversed: true);

    final history = EditorHistory().record(
      label: 'Reverse Clip',
      before: normal,
      after: reversed,
    );

    expect(history.past.single.label, 'Reverse Clip');
    expect(
      history.undo(reversed)!.snapshot.hasSameProjectState(normal),
      isTrue,
    );
  });

  test('undoes and redoes multi-step edits in order', () {
    final initial = snapshot(start: 0);
    final moved = snapshot(start: 5);
    final trimmed = snapshot(start: 5, sourceStart: 0, duration: 6);
    final split = snapshot(start: 5, sourceStart: 0, duration: 6, split: true);
    final tempo = snapshot(
      start: 5,
      sourceStart: 0,
      duration: 6,
      split: true,
      bpm: 140,
    );

    var history = EditorHistory();
    history = history.record(label: 'Move Clip', before: initial, after: moved);
    history = history.record(label: 'Trim Clip', before: moved, after: trimmed);
    history = history.record(
      label: 'Split Clip',
      before: trimmed,
      after: split,
    );
    history = history.record(
      label: 'Change Tempo',
      before: split,
      after: tempo,
    );

    var current = tempo;
    for (final expected in [split, trimmed, moved, initial]) {
      final transition = history.undo(current)!;
      current = transition.snapshot;
      history = transition.history;
      expect(current.hasSameProjectState(expected), isTrue);
    }
    expect(history.canUndo, isFalse);

    for (final expected in [moved, trimmed, split, tempo]) {
      final transition = history.redo(current)!;
      current = transition.snapshot;
      history = transition.history;
      expect(current.hasSameProjectState(expected), isTrue);
    }
    expect(history.canRedo, isFalse);
    expect(current.tracks.single.clips.last.id, 'clip-2');
  });

  test('a new edit after undo clears the redo branch', () {
    final initial = snapshot(start: 0);
    final moved = snapshot(start: 5);
    final trimmed = snapshot(start: 5, duration: 6);
    final branched = snapshot(start: 8);

    var history = EditorHistory()
        .record(label: 'Move Clip', before: initial, after: moved)
        .record(label: 'Trim Clip', before: moved, after: trimmed);
    final undo = history.undo(trimmed)!;
    history = undo.history.record(
      label: 'Move Clip',
      before: undo.snapshot,
      after: branched,
    );

    expect(history.canRedo, isFalse);
    expect(history.past.last.label, 'Move Clip');
  });

  test('ignores no-op edits and bounds the past stack', () {
    var history = EditorHistory(limit: 2);
    final initial = snapshot(start: 0);

    history = history.record(
      label: 'No-op',
      before: initial,
      after: snapshot(start: 0),
    );
    expect(history.canUndo, isFalse);

    final one = snapshot(start: 1);
    final two = snapshot(start: 2);
    final three = snapshot(start: 3);
    history = history.record(label: 'One', before: initial, after: one);
    history = history.record(label: 'Two', before: one, after: two);
    history = history.record(label: 'Three', before: two, after: three);

    expect(history.past.map((entry) => entry.label), ['Two', 'Three']);
  });

  test('snapshots share audio assets and waveform storage', () {
    final before = snapshot(start: 0);
    final after = snapshot(start: 4);

    expect(
      identical(
        before.tracks.single.clips.single.audio,
        after.tracks.single.clips.single.audio,
      ),
      isTrue,
    );
    expect(
      identical(
        before.tracks.single.clips.single.audio.waveformPeaks,
        waveform,
      ),
      isTrue,
    );
  });

  test('track name and color are independent undoable project metadata', () {
    final initial = snapshot(start: 0);
    final renamed = snapshot(start: 0, trackName: 'Vocals');
    final recolored = snapshot(
      start: 0,
      trackName: 'Vocals',
      trackColorValue: 0xFF123456,
    );

    var history = EditorHistory()
        .record(label: 'Rename Track', before: initial, after: renamed)
        .record(label: 'Change Track Color', before: renamed, after: recolored);

    expect(history.past.map((entry) => entry.label), [
      'Rename Track',
      'Change Track Color',
    ]);

    final undoColor = history.undo(recolored)!;
    expect(undoColor.snapshot.tracks.single.name, 'Vocals');
    expect(undoColor.snapshot.tracks.single.colorValue, TrackColors.purple);

    final undoRename = undoColor.history.undo(undoColor.snapshot)!;
    expect(undoRename.snapshot.tracks.single.name, 'Track');

    final redoRename = undoRename.history.redo(undoRename.snapshot)!;
    final redoColor = redoRename.history.redo(redoRename.snapshot)!;
    expect(redoColor.snapshot.tracks.single.name, 'Vocals');
    expect(redoColor.snapshot.tracks.single.colorValue, 0xFF123456);
  });

  test('track volume, mute, and solo are exact undoable mixer state', () {
    final initial = snapshot(start: 0);
    final quieter = snapshot(start: 0, volumeDb: -10);
    final muted = snapshot(start: 0, volumeDb: -10, isMuted: true);
    final soloed = snapshot(
      start: 0,
      volumeDb: -10,
      isMuted: true,
      isSolo: true,
    );

    var history = EditorHistory()
        .record(label: 'Change Track Volume', before: initial, after: quieter)
        .record(label: 'Mute Track', before: quieter, after: muted)
        .record(label: 'Solo Track', before: muted, after: soloed);

    expect(history.past.map((entry) => entry.label), [
      'Change Track Volume',
      'Mute Track',
      'Solo Track',
    ]);

    final undoSolo = history.undo(soloed)!;
    expect(undoSolo.snapshot.tracks.single.isSolo, isFalse);
    final undoMute = undoSolo.history.undo(undoSolo.snapshot)!;
    expect(undoMute.snapshot.tracks.single.isMuted, isFalse);
    final undoVolume = undoMute.history.undo(undoMute.snapshot)!;
    expect(undoVolume.snapshot.tracks.single.volumeDb, 0);

    history = EditorHistory().record(
      label: 'Change Track Volume',
      before: initial,
      after: snapshot(start: 0, volumeDb: 0),
    );
    expect(history.canUndo, isFalse);
  });

  test('track pan is exact undoable mixer state and ignores no-ops', () {
    final centered = snapshot(start: 0);
    final panned = snapshot(start: 0, pan: 0.7);

    var history = EditorHistory().record(
      label: 'Change Track Pan',
      before: centered,
      after: panned,
    );
    expect(history.past.single.label, 'Change Track Pan');

    final undo = history.undo(panned)!;
    expect(undo.snapshot.tracks.single.pan, 0);
    final redo = undo.history.redo(undo.snapshot)!;
    expect(redo.snapshot.tracks.single.pan, 0.7);

    history = EditorHistory().record(
      label: 'Change Track Pan',
      before: centered,
      after: snapshot(start: 0, pan: 0),
    );
    expect(history.canUndo, isFalse);
  });

  test('master volume is exact undoable project mixer state', () {
    final unity = snapshot(start: 0);
    final quieter = snapshot(start: 0, masterVolumeDb: -12);
    final history = EditorHistory().record(
      label: 'Change Master Volume',
      before: unity,
      after: quieter,
    );

    expect(history.past.single.label, 'Change Master Volume');
    final undo = history.undo(quieter)!;
    expect(undo.snapshot.masterVolumeDb, 0);
    final redo = undo.history.redo(undo.snapshot)!;
    expect(redo.snapshot.masterVolumeDb, -12);
  });

  test('clip fades are exact undoable arrangement state', () {
    final initial = snapshot(start: 0);
    final faded = snapshot(start: 0, fadeIn: 0.35, fadeOut: 0.5);
    final history = EditorHistory().record(
      label: 'Change Fade In',
      before: initial,
      after: faded,
    );

    expect(history.past.single.label, 'Change Fade In');
    final undo = history.undo(faded)!;
    expect(undo.snapshot.tracks.single.clips.single.fadeInDurationSeconds, 0);
    expect(undo.snapshot.tracks.single.clips.single.fadeOutDurationSeconds, 0);
    final redo = undo.history.redo(undo.snapshot)!;
    expect(
      redo.snapshot.tracks.single.clips.single.fadeInDurationSeconds,
      0.35,
    );
    expect(
      redo.snapshot.tracks.single.clips.single.fadeOutDurationSeconds,
      0.5,
    );
  });

  test('one committed clip gain change is one undo and redo step', () {
    final before = snapshot(start: 0);
    final gained = snapshot(start: 0, gainDb: -7.5);
    final history = EditorHistory().record(
      label: 'Change Clip Gain',
      before: before,
      after: gained,
    );

    expect(history.past.single.label, 'Change Clip Gain');
    final undo = history.undo(gained)!;
    expect(undo.snapshot.tracks.single.clips.single.gainDb, 0);
    final redo = undo.history.redo(undo.snapshot)!;
    expect(redo.snapshot.tracks.single.clips.single.gainDb, -7.5);
  });

  test('delete undo and redo preserve an exact trimmed split clip', () {
    final before = snapshot(
      start: 12.5,
      sourceStart: 3.2,
      duration: 9.4,
      split: true,
    );
    final left = before.tracks.single.clips.first;
    final deleted = before.tracks.single.clips.last;
    final after = ProjectSnapshot(
      tracks: [
        before.tracks.single.copyWith(clips: [left]),
      ],
      bpm: before.bpm,
      selectedTrackId: before.selectedTrackId,
      selectedClipId: null,
    );

    var history = EditorHistory().record(
      label: 'Delete Clip',
      before: before,
      after: after,
    );
    expect(history.past.single.label, 'Delete Clip');
    expect(calculateProjectDurationSeconds(after.tracks), closeTo(17.2, 1e-9));

    final undo = history.undo(after)!;
    history = undo.history;
    final restored = undo.snapshot.tracks.single.clips.last;
    expect(restored.id, deleted.id);
    expect(restored.timelineStartSeconds, closeTo(17.2, 1e-9));
    expect(restored.sourceStartSeconds, closeTo(7.9, 1e-9));
    expect(restored.clipDurationSeconds, closeTo(4.7, 1e-9));
    expect(identical(restored.audio, deleted.audio), isTrue);
    expect(undo.snapshot.selectedClipId, deleted.id);
    expect(
      calculateProjectDurationSeconds(undo.snapshot.tracks),
      closeTo(21.9, 1e-9),
    );

    final redo = history.redo(undo.snapshot)!;
    expect(redo.snapshot.tracks.single.clips, [left]);
    expect(redo.snapshot.selectedClipId, isNull);
    expect(
      calculateProjectDurationSeconds(redo.snapshot.tracks),
      closeTo(17.2, 1e-9),
    );
  });

  test('undo and redo retain multi-clip selection hints', () {
    final before = snapshot(start: 2, split: true);
    final selectedBefore = ProjectSnapshot(
      tracks: before.tracks,
      bpm: before.bpm,
      selectedTrackId: before.selectedTrackId,
      selectedClipIds: const {'clip-1', 'clip-2'},
    );
    final moved = snapshot(start: 5, split: true);
    final selectedAfter = ProjectSnapshot(
      tracks: moved.tracks,
      bpm: moved.bpm,
      selectedTrackId: moved.selectedTrackId,
      selectedClipIds: const {'clip-1', 'clip-2'},
    );

    final history = EditorHistory().record(
      label: 'Move Clips',
      before: selectedBefore,
      after: selectedAfter,
    );
    final undo = history.undo(selectedAfter)!;
    final redo = undo.history.redo(undo.snapshot)!;

    expect(undo.snapshot.selectedClipIds, {'clip-1', 'clip-2'});
    expect(redo.snapshot.selectedClipIds, {'clip-1', 'clip-2'});
    expect(redo.history.past.last.label, 'Move Clips');
  });

  test('delete track undo restores exact order, mixer, clips, and IDs', () {
    final deletedTrack = snapshot(
      start: 4.5,
      sourceStart: 1.25,
      duration: 8,
      split: true,
      trackName: 'Middle',
      trackColorValue: TrackColors.orange,
      volumeDb: -7,
      pan: 0.4,
      isMuted: true,
      isSolo: true,
      fadeIn: 0.25,
      fadeOut: 0.75,
    ).tracks.single;
    const first = DawTrack(id: 'track-a', name: 'First', clips: []);
    const last = DawTrack(id: 'track-c', name: 'Last', clips: []);
    final before = ProjectSnapshot(
      tracks: [first, deletedTrack, last],
      bpm: 120,
      selectedTrackId: deletedTrack.id,
      selectedClipIds: deletedTrack.clips.map((clip) => clip.id).toSet(),
    );
    final after = ProjectSnapshot(
      tracks: const [first, last],
      bpm: 120,
      selectedTrackId: null,
    );

    var history = EditorHistory().record(
      label: 'Delete Track',
      before: before,
      after: after,
    );
    final undo = history.undo(after)!;
    history = undo.history;

    expect(undo.snapshot.hasSameProjectState(before), isTrue);
    expect(undo.snapshot.tracks[1].id, deletedTrack.id);
    expect(identical(undo.snapshot.tracks[1].clips[0].audio, asset), isTrue);
    expect(undo.snapshot.selectedClipIds, {'clip-1', 'clip-2'});

    final redo = history.redo(undo.snapshot)!;
    expect(redo.snapshot.hasSameProjectState(after), isTrue);
    expect(redo.history.past.last.label, 'Delete Track');
  });

  test('track reorder is one undoable order-only edit with stable objects', () {
    const first = DawTrack(id: 'track-a', name: 'First', clips: []);
    final middle = snapshot(
      start: 6.25,
      sourceStart: 1.5,
      duration: 7,
      trackName: 'Vocals',
      volumeDb: -4,
      pan: -0.3,
      isMuted: true,
      fadeIn: 0.4,
      fadeOut: 0.6,
    ).tracks.single;
    const last = DawTrack(id: 'track-c', name: 'Last', clips: []);
    final before = ProjectSnapshot(
      tracks: [first, middle, last],
      bpm: 120,
      selectedTrackId: middle.id,
      selectedClipIds: {middle.clips.single.id},
    );
    final after = ProjectSnapshot(
      tracks: [last, first, middle],
      bpm: 120,
      selectedTrackId: middle.id,
      selectedClipIds: {middle.clips.single.id},
    );

    final history = EditorHistory().record(
      label: 'Reorder Tracks',
      before: before,
      after: after,
    );

    expect(history.past, hasLength(1));
    expect(history.past.single.label, 'Reorder Tracks');
    expect(identical(after.tracks[2], middle), isTrue);
    expect(after.tracks[2].clips.single.timelineStartSeconds, 6.25);
    expect(after.tracks[2].volumeDb, -4);
    expect(after.tracks[2].isMuted, isTrue);

    final undo = history.undo(after)!;
    expect(undo.snapshot.tracks.map((track) => track.id), [
      first.id,
      middle.id,
      last.id,
    ]);
    expect(identical(undo.snapshot.tracks[1], middle), isTrue);

    final redo = undo.history.redo(undo.snapshot)!;
    expect(redo.snapshot.tracks.map((track) => track.id), [
      last.id,
      first.id,
      middle.id,
    ]);
    expect(
      identical(redo.snapshot.tracks[2].clips.single.audio, asset),
      isTrue,
    );
  });

  test('recording an unchanged track order is a history no-op', () {
    const tracks = [
      DawTrack(id: 'track-a', name: 'First', clips: []),
      DawTrack(id: 'track-b', name: 'Second', clips: []),
    ];
    final before = ProjectSnapshot(
      tracks: tracks,
      bpm: 120,
      selectedTrackId: tracks.first.id,
    );
    final after = ProjectSnapshot(
      tracks: tracks,
      bpm: 120,
      selectedTrackId: tracks.first.id,
    );
    final history = EditorHistory();

    expect(
      identical(
        history.record(label: 'Reorder Tracks', before: before, after: after),
        history,
      ),
      isTrue,
    );
  });
}
