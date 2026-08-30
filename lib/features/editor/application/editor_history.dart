import 'dart:collection';

import '../domain/daw_track.dart';
import '../domain/musical_timing.dart';
import '../domain/timeline_marker.dart';
import '../domain/timeline_section.dart';

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
    Iterable<TimelineMarker> markers = const [],
    Iterable<TimelineSection> sections = const [],
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
    this.masterVolumeDb = 0,
    required this.selectedTrackId,
    Set<String> selectedClipIds = const {},
    String? selectedClipId,
  }) : tracks = List<DawTrack>.unmodifiable(tracks),
       markers = List<TimelineMarker>.unmodifiable(markers),
       sections = List<TimelineSection>.unmodifiable(sections),
       selectedClipIds = selectedClipIds.isEmpty
           ? selectedClipId == null
                 ? const {}
                 : UnmodifiableSetView({selectedClipId})
           : UnmodifiableSetView({...selectedClipIds});

  final List<DawTrack> tracks;
  final List<TimelineMarker> markers;
  final List<TimelineSection> sections;
  final double bpm;
  final TimeSignature timeSignature;
  final double masterVolumeDb;

  /// Selection is a restoration hint, not an independently undoable edit.
  final String? selectedTrackId;
  final Set<String> selectedClipIds;

  /// The selected clip when exactly one clip is selected.
  String? get selectedClipId =>
      selectedClipIds.length == 1 ? selectedClipIds.single : null;

  bool hasSameProjectState(ProjectSnapshot other) {
    if (bpm != other.bpm ||
        timeSignature != other.timeSignature ||
        masterVolumeDb != other.masterVolumeDb ||
        tracks.length != other.tracks.length ||
        markers.length != other.markers.length ||
        sections.length != other.sections.length) {
      return false;
    }

    for (var index = 0; index < sections.length; index++) {
      final left = sections[index];
      final right = other.sections[index];
      if (left.id != right.id ||
          left.startTime != right.startTime ||
          left.endTime != right.endTime ||
          left.name != right.name ||
          left.colorArgb != right.colorArgb) {
        return false;
      }
    }

    for (var markerIndex = 0; markerIndex < markers.length; markerIndex++) {
      final leftMarker = markers[markerIndex];
      final rightMarker = other.markers[markerIndex];
      if (leftMarker.id != rightMarker.id ||
          leftMarker.timeSeconds != rightMarker.timeSeconds ||
          leftMarker.name != rightMarker.name ||
          leftMarker.colorArgb != rightMarker.colorArgb) {
        return false;
      }
    }

    for (var trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
      final leftTrack = tracks[trackIndex];
      final rightTrack = other.tracks[trackIndex];
      if (leftTrack.id != rightTrack.id ||
          leftTrack.name != rightTrack.name ||
          leftTrack.colorValue != rightTrack.colorValue ||
          leftTrack.volumeDb != rightTrack.volumeDb ||
          leftTrack.pan != rightTrack.pan ||
          leftTrack.isMuted != rightTrack.isMuted ||
          leftTrack.isSolo != rightTrack.isSolo ||
          leftTrack.filterFx != rightTrack.filterFx ||
          leftTrack.eqFx != rightTrack.eqFx ||
          leftTrack.compressorFx != rightTrack.compressorFx ||
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
            leftClip.clipDurationSeconds != rightClip.clipDurationSeconds ||
            leftClip.isReversed != rightClip.isReversed ||
            leftClip.gainDb != rightClip.gainDb ||
            leftClip.fadeInDurationSeconds != rightClip.fadeInDurationSeconds ||
            leftClip.fadeOutDurationSeconds !=
                rightClip.fadeOutDurationSeconds) {
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
