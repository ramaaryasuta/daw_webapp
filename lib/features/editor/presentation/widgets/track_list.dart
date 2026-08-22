import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/snap_controller.dart';
import '../../application/tempo_controller.dart';
import '../../domain/daw_track.dart';
import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'track_header.dart';
import 'timeline_view.dart';

class TrackHeaderList extends ConsumerWidget {
  const TrackHeaderList({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: editorState.tracks.length,
      itemExtent: trackHeight,
      itemBuilder: (context, index) {
        final track = editorState.tracks[index];

        return TrackHeader(
          key: ValueKey(track.id),
          name: track.name,
          colorValue: track.colorValue,
          volumeDb: track.volumeDb,
          isMuted: track.isMuted,
          isSolo: track.isSolo,
          isSelected: editorState.selectedTrackId == track.id,
          onTap: () => controller.selectTrack(track.id),
          onRename: (name) => controller.renameTrack(track.id, name),
          onColorEditStarted: () => controller.beginTrackColorChange(track.id),
          onColorPreviewed: (colorValue) =>
              controller.previewTrackColor(track.id, colorValue),
          onColorEditCommitted: () =>
              controller.commitTrackColorChange(track.id),
          onColorEditCancelled: () =>
              controller.cancelTrackColorChange(track.id),
          onMutePressed: () => controller.toggleMute(track.id),
          onSoloPressed: () => controller.toggleSolo(track.id),
          onDeletePressed: () => controller.removeTrack(track.id),
          onVolumeChangeStart: (_) => controller.beginVolumeChange(track.id),
          onVolumeChanged: (value) => controller.previewVolume(track.id, value),
          onVolumeChangeEnd: (_) => controller.commitVolumeChange(track.id),
          onVolumeReset: () => controller.resetVolume(track.id),
        );
      },
    );
  }
}

class TimelineTrackList extends ConsumerWidget {
  const TimelineTrackList({
    super.key,
    required this.scrollController,
    required this.gridMetrics,
    required this.clipDragController,
    required this.scrollPhysics,
    required this.onSeek,
  });

  final ScrollController scrollController;
  final TimelineGridMetrics gridMetrics;
  final TimelineClipDragController clipDragController;
  final ScrollPhysics scrollPhysics;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      editorControllerProvider.select(
        (state) => _TimelineTracksSnapshot(state.tracks),
      ),
    );
    final playheadSeconds = ref.watch(
      editorControllerProvider.select((state) => state.playheadSeconds),
    );
    final selectedClipId = ref.watch(
      editorControllerProvider.select((state) => state.selectedClipId),
    );
    final bpm = ref.watch(tempoControllerProvider.select((state) => state.bpm));
    final snapSettings = ref.watch(snapControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);

    if (tracks.values.isEmpty) {
      return const _EmptyTracks();
    }

    return ListView.builder(
      controller: scrollController,
      physics: scrollPhysics,
      padding: EdgeInsets.zero,
      itemCount: tracks.values.length,
      itemExtent: trackHeight,
      itemBuilder: (context, index) {
        final track = tracks.values[index];

        return TimelineTrackLane(
          key: ValueKey(track.id),
          clips: track.clips,
          trackColorValue: track.colorValue,
          playheadSeconds: playheadSeconds,
          gridMetrics: gridMetrics,
          selectedClipId: selectedClipId,
          clipDragController: clipDragController,
          bpm: bpm,
          snapSettings: snapSettings,
          onSeek: onSeek,
          onSelect: (clipId) {
            Focus.of(context).requestFocus();
            controller.selectClip(trackId: track.id, clipId: clipId);
          },
          onMoveCommitted: (clipId, startSeconds) {
            controller.moveClip(clipId, startSeconds);
          },
          onTrimCommitted: (clipId, result) {
            controller.updateClipTrim(
              clipId: clipId,
              timelineStartSeconds: result.startSeconds,
              sourceStartSeconds: result.sourceStartSeconds,
              clipDurationSeconds: result.clipDurationSeconds,
            );
          },
        );
      },
    );
  }
}

/// Ignores mixer-only track copies so fader drags do not rebuild waveforms.
class _TimelineTracksSnapshot {
  _TimelineTracksSnapshot(Iterable<DawTrack> tracks)
    : values = List<DawTrack>.unmodifiable(tracks);

  final List<DawTrack> values;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _TimelineTracksSnapshot ||
        values.length != other.values.length) {
      return false;
    }
    for (var index = 0; index < values.length; index++) {
      final left = values[index];
      final right = other.values[index];
      if (left.id != right.id ||
          left.colorValue != right.colorValue ||
          !identical(left.clips, right.clips)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
    values.map((track) => Object.hash(track.id, track.colorValue, track.clips)),
  );
}

class _EmptyTracks extends StatelessWidget {
  const _EmptyTracks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.multitrack_audio, size: 48, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No tracks',
            style: TextStyle(fontSize: 18, color: Colors.white54),
          ),
          SizedBox(height: 4),
          Text(
            'Add a track to start editing',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
