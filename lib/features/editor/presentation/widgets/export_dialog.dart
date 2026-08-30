import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/daw_track.dart';
import '../../domain/export_settings.dart';
import '../../infrastructure/browser_audio_file.dart';
import '../../infrastructure/generated_export.dart';
import '../editor_shortcut_policy.dart';
import 'export_studio_views.dart';

Future<void> showExportDialog(
  BuildContext context, {
  required List<DawTrack> Function() createTracksSnapshot,
  required AudioExportGenerator exportGenerator,
  required VoidCallback onPreviewWillPlay,
  String projectName = 'Untitled',
  int Function()? readProjectRevision,
}) => showDialog<void>(
  context: context,
  builder: (_) => ExportDialog(
    createTracksSnapshot: createTracksSnapshot,
    exportGenerator: exportGenerator,
    onPreviewWillPlay: onPreviewWillPlay,
    projectName: projectName,
    readProjectRevision: readProjectRevision,
  ),
);

enum _Status { idle, generating, ready, stale, error }

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.createTracksSnapshot,
    required this.exportGenerator,
    required this.onPreviewWillPlay,
    this.projectName = 'Untitled',
    this.readProjectRevision,
  });

  final List<DawTrack> Function() createTracksSnapshot;
  final AudioExportGenerator exportGenerator;
  final VoidCallback onPreviewWillPlay;
  final String projectName;
  final int Function()? readProjectRevision;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late final TextEditingController _file;
  late final TextEditingController _title;
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _year = TextEditingController();
  final _track = TextEditingController();
  final _genre = TextEditingController();
  final _comment = TextEditingController();

  ExportStudioMode _mode = ExportStudioMode.general;
  ExportFormat _format = ExportFormat.wav;
  int _bitrate = 256;
  _Status _status = _Status.idle;
  ExportGenerationStage _stage = ExportGenerationStage.rendering;
  ExportRenderInfo? _renderInfo;
  GeneratedExport? _result;
  BrowserAudioFile? _audio;
  Timer? _previewTimer;
  Timer? _revisionTimer;
  double _position = 0;
  bool _playing = false;
  String? _error;
  String? _previewError;
  String? _resultFingerprint;
  int? _resultRevision;
  int _requestId = 0;

  ExportStudioGenerator? get _studio =>
      widget.exportGenerator is ExportStudioGenerator
      ? widget.exportGenerator as ExportStudioGenerator
      : null;

  List<TextEditingController> get _controllers => [
    _file,
    _title,
    _artist,
    _album,
    _year,
    _track,
    _genre,
    _comment,
  ];

  ExportSettings get _settings => ExportSettings(
    format: _format,
    mp3BitrateKbps: _bitrate,
    fileName: _file.text,
    metadata: ExportMetadata(
      title: _title.text,
      artist: _artist.text,
      album: _album.text,
      year: _year.text,
      trackNumber: _track.text,
      genre: _genre.text,
      comment: _comment.text,
    ),
  );

  bool get _hasCurrentCachedResult {
    if (_result == null ||
        _audio == null ||
        _resultFingerprint != _settings.fingerprint) {
      return false;
    }
    final revision = widget.readProjectRevision?.call();
    return _resultRevision == null || revision == _resultRevision;
  }

  @override
  void initState() {
    super.initState();
    final name = widget.projectName.trim().isEmpty
        ? 'Untitled'
        : widget.projectName.trim();
    _file = TextEditingController(text: name);
    _title = TextEditingController(text: name);
    for (final controller in _controllers) {
      controller.addListener(_settingsChanged);
    }
    final studio = _studio;
    if (studio != null) {
      try {
        _renderInfo = studio.describeExport(widget.createTracksSnapshot());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _requestId++;
    _previewTimer?.cancel();
    _revisionTimer?.cancel();
    _audio?.dispose();
    for (final controller in _controllers) {
      controller
        ..removeListener(_settingsChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _settingsChanged() {
    if (!mounted) return;
    if (_result != null && _status != _Status.generating) {
      _invalidate();
    } else {
      setState(() {});
    }
  }

  void _chooseFormat(ExportFormat value) {
    if (_format == value || _status == _Status.generating) return;
    setState(() => _format = value);
    _invalidate();
  }

  void _chooseBitrate(int value) {
    if (_bitrate == value || _status == _Status.generating) return;
    setState(() => _bitrate = value);
    _invalidate();
  }

  void _invalidate({bool projectChanged = false}) {
    if (_result == null || _status == _Status.generating) return;
    _previewTimer?.cancel();
    _revisionTimer?.cancel();
    _audio?.dispose();
    _audio = null;
    if (!mounted) return;
    setState(() {
      _status = _Status.stale;
      _playing = false;
      _position = 0;
      _error = projectChanged
          ? 'The project changed after this export was made.'
          : 'Settings changed.';
    });
  }

  Future<void> _generate() async {
    if (_status == _Status.generating) return;
    final tracks = List<DawTrack>.unmodifiable(widget.createTracksSnapshot());
    final settings = _settings;
    final revision = widget.readProjectRevision?.call();
    final id = ++_requestId;
    _previewTimer?.cancel();
    _revisionTimer?.cancel();
    _audio?.dispose();
    _audio = null;
    setState(() {
      _status = _Status.generating;
      _stage = ExportGenerationStage.rendering;
      _result = null;
      _resultFingerprint = null;
      _resultRevision = null;
      _error = null;
      _previewError = null;
      _position = 0;
      _playing = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || id != _requestId) return;

    final studio = _studio;
    try {
      final generated = studio == null
          ? await widget.exportGenerator.generateWavExport(tracks)
          : await studio.generateExport(
              tracks,
              settings,
              onStage: (stage) {
                if (mounted && id == _requestId) {
                  setState(() => _stage = stage);
                }
              },
            );
      if (!mounted || id != _requestId) return;
      if (!generated.durationSeconds.isFinite ||
          generated.durationSeconds <= 0) {
        throw StateError('Invalid generated duration.');
      }
      final audio = BrowserAudioFile(
        generated.bytes,
        mimeType: generated.mimeType,
      );
      setState(() {
        _result = generated;
        _audio = audio;
        _resultFingerprint = settings.fingerprint;
        _resultRevision = revision;
        _renderInfo = ExportRenderInfo(
          durationSeconds: generated.durationSeconds,
          sampleRate: generated.sampleRate,
          channelCount: generated.channelCount,
        );
        _status = _Status.ready;
      });
      _watchRevision();
    } catch (error, stackTrace) {
      debugPrint('[ExportDebug] export generation failed: $error\n$stackTrace');
      if (!mounted || id != _requestId) return;
      setState(() {
        _status = _Status.error;
        _error = studio == null
            ? 'Unable to generate export.'
            : switch (_stage) {
                ExportGenerationStage.rendering => 'Unable to render audio.',
                ExportGenerationStage.preparingWav =>
                  'Unable to prepare the WAV file.',
                ExportGenerationStage.encodingMp3 => 'MP3 encoding failed.',
                ExportGenerationStage.metadata =>
                  'Unable to write MP3 metadata.',
              };
      });
    }
  }

  void _watchRevision() {
    _revisionTimer?.cancel();
    if (widget.readProjectRevision == null || _resultRevision == null) return;
    _revisionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted &&
          _status == _Status.ready &&
          widget.readProjectRevision!.call() != _resultRevision) {
        _invalidate(projectChanged: true);
      }
    });
  }

  bool _isCurrent() {
    if (_status != _Status.ready || !_hasCurrentCachedResult) {
      _invalidate(
        projectChanged:
            _resultRevision != null &&
            widget.readProjectRevision?.call() != _resultRevision,
      );
      return false;
    }
    return true;
  }

  void _editSettings() {
    _previewTimer?.cancel();
    _audio?.pause();
    setState(() {
      _playing = false;
      _position = _audio?.currentPositionSeconds ?? _position;
      _status = _Status.idle;
    });
  }

  void _returnToReady() {
    if (!_hasCurrentCachedResult) {
      _invalidate();
      return;
    }
    setState(() => _status = _Status.ready);
    _watchRevision();
  }

  Future<void> _togglePreview() async {
    if (!_isCurrent() || _audio == null) return;
    final audio = _audio!;
    if (audio.isPlaying) {
      audio.pause();
      _previewTimer?.cancel();
      setState(() {
        _playing = false;
        _position = audio.currentPositionSeconds;
      });
      return;
    }
    if (audio.currentPositionSeconds >= _result!.durationSeconds - .001) {
      audio.seek(0);
      setState(() => _position = 0);
    }
    widget.onPreviewWillPlay();
    try {
      await audio.play();
      if (!mounted) return;
      setState(() {
        _previewError = null;
        _playing = audio.isPlaying;
      });
      _previewTimer?.cancel();
      _previewTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _audio == null || _result == null) return;
        final playing = _audio!.isPlaying;
        setState(() {
          _playing = playing;
          _position = _audio!.currentPositionSeconds
              .clamp(0.0, _result!.durationSeconds)
              .toDouble();
        });
        if (!playing) _previewTimer?.cancel();
      });
    } catch (error, stackTrace) {
      debugPrint('Export preview failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _playing = false;
          _previewError = 'Unable to play the rendered preview.';
        });
      }
    }
  }

  void _seek(double value) {
    if (!_isCurrent() || _audio == null || _result == null) return;
    final position = value.clamp(0.0, _result!.durationSeconds).toDouble();
    _audio!.seek(position);
    setState(() => _position = position);
  }

  void _download() {
    if (_isCurrent()) _audio?.download(fileName: _result!.fileName);
  }

  int _estimate(ExportFormat format) {
    final info = _renderInfo;
    if (info == null) return 0;
    return estimateExportBytes(
      format: format,
      durationSeconds: info.durationSeconds,
      sampleRate: info.sampleRate,
      channelCount: info.channelCount,
      mp3BitrateKbps: _bitrate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final dialogHeight = math.max(280.0, math.min(650.0, screen.height - 32));
    return Dialog(
      backgroundColor: colors.surfaceContainer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: EditorShortcutScope(
        child: SizedBox(
          width: 800,
          height: dialogHeight,
          child: Column(
            children: [
              _header(context),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 230),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, .025),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: switch (_status) {
                      _Status.generating => ExportProcessingView(
                        stage: _stage,
                        format: _format,
                        bitrateKbps: _bitrate,
                      ),
                      _Status.ready => ExportReadyView(
                        result: _result!,
                        bitrateKbps: _bitrate,
                        estimatedBytes: _estimate(_result!.format),
                        positionSeconds: _position,
                        isPlaying: _playing,
                        previewError: _previewError,
                        onPlayPause: _togglePreview,
                        onSeek: _seek,
                      ),
                      _ => ExportConfigurationView(
                        mode: _mode,
                        onModeChanged: (value) => setState(() => _mode = value),
                        format: _format,
                        onFormatChanged: _chooseFormat,
                        bitrateKbps: _bitrate,
                        onBitrateChanged: _chooseBitrate,
                        renderInfo: _renderInfo,
                        estimatedBytes: _estimate,
                        fileNameController: _file,
                        titleController: _title,
                        artistController: _artist,
                        albumController: _album,
                        yearController: _year,
                        trackController: _track,
                        genreController: _genre,
                        commentController: _comment,
                        notice: _configurationNotice,
                        noticeIsError: _status == _Status.error,
                      ),
                    },
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  String? get _configurationNotice => switch (_status) {
    _Status.stale =>
      '${_error ?? 'Settings changed.'} Generate again to update the export.',
    _Status.error => _error ?? 'Unable to generate export.',
    _ => null,
  };

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 10, 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .12),
              border: Border.all(color: colors.primary.withValues(alpha: .35)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.graphic_eq, size: 19, color: colors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPORT STUDIO',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
                Text(
                  'OUTPUT  \u00b7  RENDER  \u00b7  DOWNLOAD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: .45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _status == _Status.generating
                ? 'Export is still processing'
                : 'Close',
            onPressed: _status == _Status.generating
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final isReady = _status == _Status.ready;
    final isGenerating = _status == _Status.generating;
    const compactButtonStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          TextButton(
            style: compactButtonStyle,
            onPressed: isGenerating
                ? null
                : isReady
                ? _editSettings
                : () => Navigator.of(context).pop(),
            child: Text(isReady ? 'Edit Settings' : 'Close'),
          ),
          const Spacer(),
          if (!isReady && !isGenerating && _hasCurrentCachedResult) ...[
            OutlinedButton(
              style: compactButtonStyle,
              onPressed: _returnToReady,
              child: const Text('Back to Export'),
            ),
            const SizedBox(width: 8),
          ],
          switch (_status) {
            _Status.generating => FilledButton.icon(
              style: compactButtonStyle,
              onPressed: null,
              icon: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('Generating...'),
            ),
            _Status.ready => FilledButton.icon(
              style: compactButtonStyle,
              onPressed: _download,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text('Download ${_result!.format.label}'),
            ),
            _Status.error => FilledButton.icon(
              style: compactButtonStyle,
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
            _ => FilledButton.icon(
              style: compactButtonStyle,
              onPressed: _generate,
              icon: const Icon(Icons.graphic_eq, size: 18),
              label: const Text('Generate Export'),
            ),
          },
        ],
      ),
    );
  }
}
