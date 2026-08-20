import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/editor_controller.dart';
import 'widgets/track_header.dart';
import 'widgets/track_list.dart';
import 'widgets/timeline_ruler.dart';
import 'widgets/transport_bar.dart';

import 'package:desktop_drop/desktop_drop.dart';
import '../infrastructure/audio_import_service.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  bool _isDragging = false;

  Future<void> _pickAudioFiles() async {
    final importer = ref.read(audioImportServiceProvider);

    final result = await importer.pickAudioFiles();

    await _applyImportResult(result);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() {
      _isDragging = false;
    });

    final importer = ref.read(audioImportServiceProvider);

    final result = await importer.importDroppedItems(details.files);

    await _applyImportResult(result);
  }

  Future<void> _applyImportResult(AudioImportResult result) async {
    if (!mounted) {
      return;
    }

    final rejected = <String>[...result.rejectedFiles];

    if (result.files.isNotEmpty) {
      final decodeFailures = await ref
          .read(editorControllerProvider.notifier)
          .importAudioFiles(result.files);

      rejected.addAll(decodeFailures);
    }

    if (!mounted) {
      return;
    }

    if (rejected.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not import: '
            '${rejected.join(', ')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);

    final controller = ref.read(editorControllerProvider.notifier);

    return Scaffold(
      body: DropTarget(
        onDragEntered: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (details) {
          _handleDrop(details);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  TransportBar(
                    isPlaying: editorState.isPlaying,
                    isImporting: editorState.isImporting,
                    positionSeconds: editorState.playheadSeconds,
                    onPlayPressed: controller.togglePlayback,
                    onStopPressed: controller.stop,

                    onAddTrackPressed: editorState.isImporting
                        ? null
                        : _pickAudioFiles,
                  ),

                  _TimelineHeader(
                    playheadSeconds: editorState.playheadSeconds,
                    onSeek: controller.seek,
                  ),

                  const Expanded(child: TrackList()),
                ],
              ),
            ),

            if (_isDragging) const Positioned.fill(child: _DropOverlay()),
          ],
        ),
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({required this.playheadSeconds, required this.onSeek});

  final double playheadSeconds;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: TimelineRuler.height,
      child: Row(
        children: [
          Container(
            width: trackHeaderWidth,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant),
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: const Center(
              child: Text(
                'TRACKS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          Expanded(
            child: TimelineRuler(
              playheadSeconds: playheadSeconds,
              onSeek: onSeek,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audio_file, size: 48),
                SizedBox(height: 16),
                Text(
                  'Drop audio files here',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text('WAV or MP3'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
