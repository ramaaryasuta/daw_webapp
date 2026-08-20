import 'package:flutter/material.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.isImporting,
    required this.positionSeconds,
    required this.onPlayPressed,
    required this.onStopPressed,
    required this.onAddTrackPressed,
  });

  final bool isPlaying;
  final bool isImporting;
  final double positionSeconds;

  final VoidCallback onPlayPressed;
  final VoidCallback onStopPressed;
  final VoidCallback? onAddTrackPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Stop',
            onPressed: onStopPressed,
            icon: const Icon(Icons.stop),
          ),

          const SizedBox(width: 4),

          IconButton.filled(
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: onPlayPressed,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          ),

          const SizedBox(width: 24),

          Text(_formatTime(positionSeconds)),

          const Spacer(),

          // Tambahkan di sini
          if (isImporting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          FilledButton.icon(
            onPressed: onAddTrackPressed,
            icon: const Icon(Icons.library_music),
            label: const Text('Import Audio'),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final totalMilliseconds = (seconds * 1000).floor();

    final minutes = totalMilliseconds ~/ 60000;

    final remainingMilliseconds = totalMilliseconds % 60000;

    final secs = remainingMilliseconds ~/ 1000;

    final millis = remainingMilliseconds % 1000;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}
