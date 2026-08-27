import 'package:daw_webapp/features/editor/application/editor_history.dart';
import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
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

  ProjectSnapshot snapshot({
    required double start,
    double sourceStart = 0,
    double duration = 10,
    double bpm = 120,
    bool split = false,
    String trackName = 'Track',
    int trackColorValue = TrackColors.purple,
    double volumeDb = 0,
    double pan = 0,
    bool isMuted = false,
    bool isSolo = false,
    double fadeIn = 0,
    double fadeOut = 0,
  }) {
    final original = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: start,
      sourceStartSeconds: sourceStart,
      clipDurationSeconds: duration,
      fadeInDurationSeconds: fadeIn,
      fadeOutDurationSeconds: fadeOut,
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
      selectedTrackId: 'track-1',
      selectedClipId: split ? 'clip-2' : 'clip-1',
    );
  }

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
}
