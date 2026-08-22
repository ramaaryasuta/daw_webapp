import '../domain/daw_track.dart';

/// Maximum number of committed project edits retained for undo.
const int editorHistoryLimit = 100;

/// Lightweight, immutable view of the persistent project arrangement.
///
/// Track, clip, and audio-asset objects are immutable and intentionally shared
/// between snapshots. In particular, waveform arrays and Web Audio buffers are
/// never copied into history.
class ProjectSnapshot {
  ProjectSnapshot({
    required Iterable<DawTrack> tracks,
    required this.bpm,
    required this.selectedTrackId,
    required this.selectedClipId,
  }) : tracks = List<DawTrack>.unmodifiable(tracks);

  final List<DawTrack> tracks;
  final double bpm;

  /// Selection is a restoration hint, not an independently undoable edit.
  final String? selectedTrackId;
  final String? selectedClipId;

  bool hasSameProjectState(ProjectSnapshot other) {
    if (bpm != other.bpm || tracks.length != other.tracks.length) {
      return false;
    }

    for (var trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
      final leftTrack = tracks[trackIndex];
      final rightTrack = other.tracks[trackIndex];
      if (leftTrack.id != rightTrack.id ||
          leftTrack.name != rightTrack.name ||
          leftTrack.colorValue != rightTrack.colorValue ||
          leftTrack.volumeDb != rightTrack.volumeDb ||
          leftTrack.isMuted != rightTrack.isMuted ||
          leftTrack.isSolo != rightTrack.isSolo ||
          leftTrack.clips.length != rightTrack.clips.length) {
        return false;
      }

      for (var clipIndex = 0; clipIndex < leftTrack.clips.length; clipIndex++) {
        final leftClip = leftTrack.clips[clipIndex];
        final rightClip = rightTrack.clips[clipIndex];
        if (leftClip.id != rightClip.id ||
            leftClip.audio.id != rightClip.audio.id ||
            leftClip.timelineStartSeconds != rightClip.timelineStartSeconds ||
            leftClip.sourceStartSeconds != rightClip.sourceStartSeconds ||
            leftClip.clipDurationSeconds != rightClip.clipDurationSeconds) {
          return false;
        }
      }
    }

    return true;
  }
}

class EditorHistoryEntry {
  const EditorHistoryEntry({required this.label, required this.snapshot});

  final String label;
  final ProjectSnapshot snapshot;
}

/// Immutable past/future stacks.
///
/// Both stacks use their last element as the top. Undo moves the current
/// project onto [future]; redo moves it back onto [past].
class EditorHistory {
  EditorHistory({
    Iterable<EditorHistoryEntry> past = const [],
    Iterable<EditorHistoryEntry> future = const [],
    this.limit = editorHistoryLimit,
  }) : assert(limit > 0),
       past = List<EditorHistoryEntry>.unmodifiable(past),
       future = List<EditorHistoryEntry>.unmodifiable(future);

  final List<EditorHistoryEntry> past;
  final List<EditorHistoryEntry> future;
  final int limit;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;
  String? get undoLabel => canUndo ? past.last.label : null;
  String? get redoLabel => canRedo ? future.last.label : null;

  EditorHistory record({
    required String label,
    required ProjectSnapshot before,
    required ProjectSnapshot after,
  }) {
    if (before.hasSameProjectState(after)) {
      return this;
    }

    final nextPast = [
      ...past,
      EditorHistoryEntry(label: label, snapshot: before),
    ];
    if (nextPast.length > limit) {
      nextPast.removeRange(0, nextPast.length - limit);
    }

    return EditorHistory(past: nextPast, limit: limit);
  }

  EditorHistoryTransition? undo(ProjectSnapshot current) {
    if (!canUndo) {
      return null;
    }

    final entry = past.last;
    return EditorHistoryTransition(
      snapshot: entry.snapshot,
      history: EditorHistory(
        past: past.take(past.length - 1),
        future: [
          ...future,
          EditorHistoryEntry(label: entry.label, snapshot: current),
        ],
        limit: limit,
      ),
    );
  }

  EditorHistoryTransition? redo(ProjectSnapshot current) {
    if (!canRedo) {
      return null;
    }

    final entry = future.last;
    final nextPast = [
      ...past,
      EditorHistoryEntry(label: entry.label, snapshot: current),
    ];
    if (nextPast.length > limit) {
      nextPast.removeRange(0, nextPast.length - limit);
    }

    return EditorHistoryTransition(
      snapshot: entry.snapshot,
      history: EditorHistory(
        past: nextPast,
        future: future.take(future.length - 1),
        limit: limit,
      ),
    );
  }
}

class EditorHistoryTransition {
  const EditorHistoryTransition({
    required this.snapshot,
    required this.history,
  });

  final ProjectSnapshot snapshot;
  final EditorHistory history;
}
