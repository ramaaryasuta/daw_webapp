import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/daw_track.dart';
import '../../infrastructure/browser_audio_file.dart';
import '../../infrastructure/generated_export.dart';
import '../formatters/export_duration_formatter.dart';

Future<void> showExportDialog(
  BuildContext context, {
  required List<DawTrack> Function() createTracksSnapshot,
  required AudioExportGenerator exportGenerator,
  required VoidCallback onPreviewWillPlay,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => ExportDialog(
      createTracksSnapshot: createTracksSnapshot,
      exportGenerator: exportGenerator,
      onPreviewWillPlay: onPreviewWillPlay,
    ),
  );
}

enum _ExportStatus { idle, generating, ready, error }

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.createTracksSnapshot,
    required this.exportGenerator,
    required this.onPreviewWillPlay,
  });

  final List<DawTrack> Function() createTracksSnapshot;
  final AudioExportGenerator exportGenerator;
  final VoidCallback onPreviewWillPlay;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  static const _previewRefreshInterval = Duration(milliseconds: 100);

  _ExportStatus _status = _ExportStatus.idle;
  GeneratedExport? _generatedExport;
  BrowserAudioFile? _audioFile;
  Timer? _previewTicker;
  String? _generationError;
  String? _previewError;
  double _previewPositionSeconds = 0;
  bool _isPreviewPlaying = false;
  int _generationRequestId = 0;

  @override
  void dispose() {
    _generationRequestId++;
    _stopPreviewTicker();
    _audioFile?.dispose();
    super.dispose();
  }

  Future<void> _generateExport() async {
    if (_status == _ExportStatus.generating) {
      return;
    }

    final tracks = List<DawTrack>.unmodifiable(widget.createTracksSnapshot());
    final requestId = ++_generationRequestId;
    _stopPreviewTicker();
    _audioFile?.dispose();
    _audioFile = null;

    setState(() {
      _status = _ExportStatus.generating;
      _generatedExport = null;
      _generationError = null;
      _previewError = null;
      _previewPositionSeconds = 0;
      _isPreviewPlaying = false;
    });

    // Let Flutter paint the generating state before offline rendering and WAV
    // encoding begin. This is a frame yield, not an artificial loading delay.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _generationRequestId) {
      return;
    }

    try {
      final generatedExport = await widget.exportGenerator.generateWavExport(
        tracks,
      );

      if (!mounted || requestId != _generationRequestId) {
        return;
      }

      if (!generatedExport.durationSeconds.isFinite ||
          generatedExport.durationSeconds <= 0) {
        throw StateError(
          'Generated export has invalid duration: '
          '${generatedExport.durationSeconds}',
        );
      }

      final audioFile = BrowserAudioFile.wav(generatedExport.wavBytes);

      setState(() {
        _generatedExport = generatedExport;
        _audioFile = audioFile;
        _status = _ExportStatus.ready;
      });
    } catch (error, stackTrace) {
      debugPrint('[ExportDebug] export generation failed: $error\n$stackTrace');
      if (!mounted || requestId != _generationRequestId) {
        return;
      }

      setState(() {
        _status = _ExportStatus.error;
        _generationError = 'Unable to generate export.';
      });
    }
  }

  Future<void> _togglePreview() async {
    final audioFile = _audioFile;
    if (audioFile == null) {
      return;
    }

    if (audioFile.isPlaying) {
      audioFile.pause();
      _stopPreviewTicker();
      setState(() {
        _isPreviewPlaying = false;
        _previewPositionSeconds = audioFile.currentPositionSeconds;
      });
      return;
    }

    final generatedExport = _generatedExport;
    if (generatedExport != null &&
        audioFile.currentPositionSeconds >=
            generatedExport.durationSeconds - 0.001) {
      audioFile.seek(0);
      setState(() {
        _previewPositionSeconds = 0;
      });
    }

    widget.onPreviewWillPlay();
    try {
      await audioFile.play();
      if (!mounted) {
        return;
      }

      setState(() {
        _previewError = null;
        _isPreviewPlaying = audioFile.isPlaying;
      });
      _startPreviewTicker();
    } catch (error, stackTrace) {
      debugPrint('Export preview playback failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreviewPlaying = false;
        _previewError = 'Unable to play the rendered preview.';
      });
    }
  }

  void _seekPreview(double positionSeconds) {
    final audioFile = _audioFile;
    final generatedExport = _generatedExport;
    if (audioFile == null || generatedExport == null) {
      return;
    }

    final position = positionSeconds
        .clamp(0.0, generatedExport.durationSeconds)
        .toDouble();
    audioFile.seek(position);
    setState(() {
      _previewPositionSeconds = position;
      _previewError = null;
    });
  }

  void _startPreviewTicker() {
    _previewTicker?.cancel();
    _previewTicker = Timer.periodic(_previewRefreshInterval, (_) {
      if (!mounted) {
        _stopPreviewTicker();
        return;
      }

      final audioFile = _audioFile;
      final generatedExport = _generatedExport;
      if (audioFile == null || generatedExport == null) {
        _stopPreviewTicker();
        return;
      }

      final position = audioFile.currentPositionSeconds
          .clamp(0.0, generatedExport.durationSeconds)
          .toDouble();
      final isPlaying = audioFile.isPlaying;

      setState(() {
        _previewPositionSeconds = position;
        _isPreviewPlaying = isPlaying;
      });

      if (!isPlaying) {
        _stopPreviewTicker();
      }
    });
  }

  void _stopPreviewTicker() {
    _previewTicker?.cancel();
    _previewTicker = null;
  }

  void _download() {
    final audioFile = _audioFile;
    final generatedExport = _generatedExport;
    if (audioFile == null || generatedExport == null) {
      return;
    }

    audioFile.download(fileName: generatedExport.fileName);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: screenSize.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Audio',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a final stereo WAV mix of your arrangement.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_status) {
                    _ExportStatus.idle => const _IdleContent(
                      key: ValueKey('idle'),
                    ),
                    _ExportStatus.generating => const _GeneratingContent(
                      key: ValueKey('generating'),
                    ),
                    _ExportStatus.ready => _ReadyContent(
                      key: const ValueKey('ready'),
                      generatedExport: _generatedExport!,
                      positionSeconds: _previewPositionSeconds,
                      isPlaying: _isPreviewPlaying,
                      previewError: _previewError,
                      onPlayPause: _togglePreview,
                      onSeek: _seekPreview,
                    ),
                    _ExportStatus.error => _ErrorContent(
                      key: const ValueKey('error'),
                      message: _generationError ?? 'Unable to generate export.',
                    ),
                  },
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (_status == _ExportStatus.ready) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _generateExport,
                      child: const Text('Regenerate'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  switch (_status) {
                    _ExportStatus.idle => FilledButton.icon(
                      onPressed: _generateExport,
                      icon: const Icon(Icons.graphic_eq, size: 18),
                      label: const Text('Generate Export'),
                    ),
                    _ExportStatus.generating => FilledButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Generating...'),
                    ),
                    _ExportStatus.ready => FilledButton.icon(
                      onPressed: _download,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download WAV'),
                    ),
                    _ExportStatus.error => FilledButton.icon(
                      onPressed: _generateExport,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleContent extends StatelessWidget {
  const _IdleContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generate a final WAV mix of the current arrangement.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ExportMetadata(label: 'Format', value: 'WAV / PCM 16-bit'),
              _ExportMetadata(label: 'Channels', value: 'Stereo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneratingContent extends StatelessWidget {
  const _GeneratingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            const Text('Generating export...'),
            const SizedBox(height: 6),
            Text(
              'Rendering the mix and preparing the WAV',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    super.key,
    required this.generatedExport,
    required this.positionSeconds,
    required this.isPlaying,
    required this.previewError,
    required this.onPlayPause,
    required this.onSeek,
  });

  final GeneratedExport generatedExport;
  final double positionSeconds;
  final bool isPlaying;
  final String? previewError;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ready to export',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const _ExportMetadata(label: 'Format', value: 'WAV / PCM 16-bit'),
            _ExportMetadata(
              label: 'Channels',
              value: generatedExport.channelCount == 2
                  ? 'Stereo'
                  : '${generatedExport.channelCount}',
            ),
            _ExportMetadata(
              label: 'Duration',
              value: formatExportDuration(generatedExport.durationSeconds),
            ),
            _ExportMetadata(
              label: 'Sample rate',
              value: '${generatedExport.sampleRate} Hz',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: isPlaying ? 'Pause preview' : 'Play preview',
                    onPressed: onPlayPause,
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  const SizedBox(width: 8),
                  Text(formatExportDuration(positionSeconds)),
                  Expanded(
                    child: Slider(
                      value: positionSeconds.clamp(
                        0.0,
                        generatedExport.durationSeconds,
                      ),
                      min: 0,
                      max: generatedExport.durationSeconds,
                      onChanged: onSeek,
                    ),
                  ),
                  Text(formatExportDuration(generatedExport.durationSeconds)),
                ],
              ),
              if (previewError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    previewError!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportMetadata extends StatelessWidget {
  const _ExportMetadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 210,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 38),
            const SizedBox(height: 14),
            Text(message),
          ],
        ),
      ),
    );
  }
}
