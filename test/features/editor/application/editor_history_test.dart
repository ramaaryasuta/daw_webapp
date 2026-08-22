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
  }) {
    final original = AudioClip(
      id: 'clip-1',
      audio: asset,
      timelineStartSeconds: start,
      sourceStartSeconds: sourceStart,
      clipDurationSeconds: duration,
    );
    return ProjectSnapshot(
      tracks: [
        DawTrack(
          id: 'track-1',
          name: trackName,
          colorValue: trackColorValue,
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
}
