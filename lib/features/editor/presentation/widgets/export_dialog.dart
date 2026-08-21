import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/daw_track.dart';
import '../../infrastructure/audio_mixdown_service.dart';
import '../../infrastructure/browser_audio_file.dart';

Future<void> showExportDialog(
  BuildContext context, {
  required List<DawTrack> tracks,
  required AudioMixdownService mixdownService,
  required VoidCallback onPreviewWillPlay,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => ExportDialog(
      tracks: tracks,
      mixdownService: mixdownService,
      onPreviewWillPlay: onPreviewWillPlay,
    ),
  );
}

enum _ExportStatus { rendering, ready, error }

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.tracks,
    required this.mixdownService,
    required this.onPreviewWillPlay,
  });

  final List<DawTrack> tracks;
  final AudioMixdownService mixdownService;
  final VoidCallback onPreviewWillPlay;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  static const _previewRefreshInterval = Duration(milliseconds: 100);

  _ExportStatus _status = _ExportStatus.rendering;
  RenderedAudioMix? _renderedMix;
  BrowserAudioFile? _audioFile;
  Timer? _previewTicker;
  String? _renderError;
  String? _previewError;
  double _previewPositionSeconds = 0;
  bool _isPreviewPlaying = false;
  int _renderRequestId = 0;

  @override
  void initState() {
    super.initState();
    _renderMix();
  }

  @override
  void dispose() {
    _renderRequestId++;
    _stopPreviewTicker();
    _audioFile?.dispose();
    super.dispose();
  }

  Future<void> _renderMix() async {
    final requestId = ++_renderRequestId;
    _stopPreviewTicker();
    _audioFile?.dispose();
    _audioFile = null;

    if (mounted) {
      setState(() {
        _status = _ExportStatus.rendering;
        _renderedMix = null;
        _renderError = null;
        _previewError = null;
        _previewPositionSeconds = 0;
        _isPreviewPlaying = false;
      });
    }

    try {
      final renderedMix = await widget.mixdownService.renderStereoWav(
        widget.tracks,
      );

      if (!mounted || requestId != _renderRequestId) {
        return;
      }

      final audioFile = BrowserAudioFile.wav(renderedMix.wavBytes);

      setState(() {
        _renderedMix = renderedMix;
        _audioFile = audioFile;
        _status = _ExportStatus.ready;
      });
    } catch (error, stackTrace) {
      debugPrint('Audio export failed: $error\n$stackTrace');
      if (!mounted || requestId != _renderRequestId) {
        return;
      }

      setState(() {
        _status = _ExportStatus.error;
        _renderError = 'Unable to render the project.';
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

    final renderedMix = _renderedMix;
    if (renderedMix != null &&
        audioFile.currentPositionSeconds >=
            renderedMix.durationSeconds - 0.001) {
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
    final renderedMix = _renderedMix;
    if (audioFile == null || renderedMix == null) {
      return;
    }

    final position = positionSeconds
        .clamp(0.0, renderedMix.durationSeconds)
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
      final renderedMix = _renderedMix;
      if (audioFile == null || renderedMix == null) {
        _stopPreviewTicker();
        return;
      }

      final position = audioFile.currentPositionSeconds
          .clamp(0.0, renderedMix.durationSeconds)
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
    _audioFile?.download();
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
                          'Final stereo mix',
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
                    _ExportStatus.rendering => const _RenderingContent(
                      key: ValueKey('rendering'),
                    ),
                    _ExportStatus.ready => _ReadyContent(
                      key: const ValueKey('ready'),
                      renderedMix: _renderedMix!,
                      positionSeconds: _previewPositionSeconds,
                      isPlaying: _isPreviewPlaying,
                      previewError: _previewError,
                      onPlayPause: _togglePreview,
                      onSeek: _seekPreview,
                    ),
                    _ExportStatus.error => _ErrorContent(
                      key: const ValueKey('error'),
                      message: _renderError ?? 'Unable to render the project.',
                      onRetry: _renderMix,
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
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _status == _ExportStatus.ready
                        ? _download
                        : null,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export WAV'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenderingContent extends StatelessWidget {
  const _RenderingContent({super.key});

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
            const Text('Rendering mix...'),
            const SizedBox(height: 6),
            Text(
              'Preparing a stereo WAV preview',
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
    required this.renderedMix,
    required this.positionSeconds,
    required this.isPlaying,
    required this.previewError,
    required this.onPlayPause,
    required this.onSeek,
  });

  final RenderedAudioMix renderedMix;
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const _ExportMetadata(label: 'Format', value: 'WAV / PCM 16-bit'),
            _ExportMetadata(
              label: 'Channels',
              value: renderedMix.channelCount == 2
                  ? 'Stereo'
                  : '${renderedMix.channelCount}',
            ),
            _ExportMetadata(
              label: 'Duration',
              value: _formatDuration(renderedMix.durationSeconds),
            ),
            _ExportMetadata(
              label: 'Sample rate',
              value: '${renderedMix.sampleRate} Hz',
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
                  Text(_formatDuration(positionSeconds)),
                  Expanded(
                    child: Slider(
                      value: positionSeconds.clamp(
                        0.0,
                        renderedMix.durationSeconds,
                      ),
                      min: 0,
                      max: renderedMix.durationSeconds,
                      onChanged: onSeek,
                    ),
                  ),
                  Text(_formatDuration(renderedMix.durationSeconds)),
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
  const _ErrorContent({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

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
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(double seconds) {
  final totalMilliseconds = (seconds * 1000).round().clamp(0, 1 << 52);
  final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (totalMilliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final wholeSeconds =
      (totalMilliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final milliseconds = totalMilliseconds % 1000;
  final prefix = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';

  return '$prefix${minutes.toString().padLeft(2, '0')}:'
      '${wholeSeconds.toString().padLeft(2, '0')}.'
      '${milliseconds.toString().padLeft(3, '0')}';
}
