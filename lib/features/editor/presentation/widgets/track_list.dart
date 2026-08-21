import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
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
          name: track.name,
          volume: track.volume,
          isMuted: track.isMuted,
          isSolo: track.isSolo,
          isSelected: editorState.selectedTrackId == track.id,
          onTap: () => controller.selectTrack(track.id),
          onMutePressed: () => controller.toggleMute(track.id),
          onSoloPressed: () => controller.toggleSolo(track.id),
          onDeletePressed: () => controller.removeTrack(track.id),
          onVolumeChanged: (value) => controller.setVolume(track.id, value),
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
    final editorState = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);

    if (editorState.tracks.isEmpty) {
      return const _EmptyTracks();
    }

    return ListView.builder(
      controller: scrollController,
      physics: scrollPhysics,
      padding: EdgeInsets.zero,
      itemCount: editorState.tracks.length,
      itemExtent: trackHeight,
      itemBuilder: (context, index) {
        final track = editorState.tracks[index];

        return TimelineTrackLane(
          key: ValueKey(track.id),
          clips: track.clips,
          playheadSeconds: editorState.playheadSeconds,
          gridMetrics: gridMetrics,
          selectedClipId: editorState.selectedClipId,
          clipDragController: clipDragController,
          onSeek: onSeek,
          onSelect: (clipId) =>
              controller.selectClip(trackId: track.id, clipId: clipId),
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
