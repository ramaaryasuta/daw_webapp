import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import 'track_header.dart';
import 'timeline_view.dart';

class TrackList extends ConsumerWidget {
  const TrackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorControllerProvider);

    final controller = ref.read(editorControllerProvider.notifier);

    if (editorState.tracks.isEmpty) {
      return const _EmptyTracks();
    }

    return ListView.builder(
      itemCount: editorState.tracks.length,
      itemExtent: trackHeight,
      itemBuilder: (context, index) {
        final track = editorState.tracks[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackHeader(
              name: track.name,
              volume: track.volume,
              isMuted: track.isMuted,
              isSolo: track.isSolo,
              isSelected: editorState.selectedTrackId == track.id,
              onTap: () {
                controller.selectTrack(track.id);
              },
              onMutePressed: () {
                controller.toggleMute(track.id);
              },
              onSoloPressed: () {
                controller.toggleSolo(track.id);
              },
              onDeletePressed: () {
                controller.removeTrack(track.id);
              },
              onVolumeChanged: (value) {
                controller.setVolume(track.id, value);
              },
            ),

            Expanded(
              child: TimelineTrackLane(
                fileName: track.audio.name,
                durationSeconds: track.audio.durationSeconds,
                startTimeSeconds: track.startTimeSeconds,
                waveformPeaks: track.audio.waveformPeaks,
                playheadSeconds: editorState.playheadSeconds,
                onSeek: controller.seek,
              ),
            ),
          ],
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
