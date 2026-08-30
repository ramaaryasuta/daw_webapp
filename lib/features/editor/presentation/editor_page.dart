import 'dart:async';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../application/editor_controller.dart';
import '../application/snap_controller.dart';
import '../application/tempo_controller.dart';
import '../domain/daw_track.dart';
import '../domain/loop_region.dart';
import '../domain/timeline_scale.dart';
import '../domain/timeline_snapper.dart';
import '../infrastructure/audio_import_service.dart';
import '../infrastructure/audio_mixdown_service.dart';
import '../infrastructure/browser_before_unload.dart';
import '../infrastructure/project_io/flaudio_project_codec.dart';
import '../infrastructure/project_io/flaudio_project_io_service.dart';
import '../infrastructure/project_io/project_autosave_store.dart';
import '../infrastructure/project_io/project_dto.dart';
import '../infrastructure/web_audio_engine.dart';
import 'controllers/audio_meter_controller.dart';
import 'controllers/timeline_clip_drag_controller.dart';
import 'controllers/track_reorder_drag_controller.dart';
import 'editor_shortcut_policy.dart';
import 'intents/clip_clipboard_intents.dart';
import 'intents/delete_clip_intent.dart';
import 'intents/edit_history_intents.dart';
import 'intents/play_pause_intent.dart';
import 'intents/split_clip_intent.dart';
import 'intents/toggle_loop_intent.dart';
import 'models/app_command.dart';
import 'models/timeline_ruler_mode.dart';
import 'widgets/commands_dialog.dart';
import 'widgets/editor_menu_bar.dart';
import 'widgets/export_dialog.dart';
import 'widgets/project_progress_dialog.dart';
import 'widgets/project_recovery_dialog.dart';
import 'widgets/save_project_dialog.dart';
import 'widgets/track_header.dart';
import 'widgets/track_list.dart';
import 'widgets/timeline_ruler.dart';
import 'widgets/timeline_loop_overlay.dart';
import 'widgets/transport_bar.dart';

typedef _PlaybackFollowState = ({
  bool isPlaying,
  double playheadSeconds,
  double pixelsPerSecond,
});

class _ClearClipSelectionIntent extends Intent {
  const _ClearClipSelectionIntent();
}

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const _playheadFollowResumeDelay = Duration(seconds: 3);
  static const _playheadFollowThresholdFraction = 0.75;

  bool _isDraggingOverWorkspace = false;
  bool _isProjectOperationInProgress = false;
  bool _isSyncingVerticalScroll = false;
  bool _isProgrammaticTimelineScroll = false;
  bool _isTimelinePanning = false;
  bool _isAutosaveWriting = false;
  int? _timelinePanPointer;
  double _timelinePanStartGlobalX = 0;
  double _timelinePanStartScrollOffset = 0;
  double? _pendingHorizontalOffset;
  double? _lastPanZoomScale;
  DateTime? _lastTimelineInteraction;
  TimelineRulerMode _rulerMode = TimelineRulerMode.barsBeats;
  _AutosaveStatus _autosaveStatus = _AutosaveStatus.idle;
  String? _autosaveError;
  Timer? _autosaveTimer;

  final GlobalKey _timelineViewportKey = GlobalKey();
  final GlobalKey _trackLaneViewportKey = GlobalKey();

  late final ScrollController _horizontalTimelineController;
  late final ScrollController _trackHeaderScrollController;
  late final ScrollController _trackLaneScrollController;
  late final TimelineClipDragController _clipDragController;
  late final TrackReorderDragController _trackReorderController;
  late final ValueNotifier<LoopRegion?> _loopPreviewRegion;
  late final AudioMeterController _audioMeterController;
  late final BrowserBeforeUnloadGuard _beforeUnloadGuard;

  @override
  void initState() {
    super.initState();

    _horizontalTimelineController = ScrollController();
    _trackHeaderScrollController = ScrollController();
    _trackLaneScrollController = ScrollController();
    _loopPreviewRegion = ValueNotifier<LoopRegion?>(null);
    _audioMeterController = AudioMeterController(
      ref.read(webAudioEngineProvider),
    );
    _beforeUnloadGuard = createBrowserBeforeUnloadGuard();
    _clipDragController = TimelineClipDragController(
      _horizontalTimelineController,
      _timelineViewportKey,
      _markTimelineUserInteraction,
      verticalScrollController: _trackLaneScrollController,
      trackViewportKey: _trackLaneViewportKey,
    );
    _trackReorderController = TrackReorderDragController();

    _trackHeaderScrollController.addListener(_syncLanesToHeaders);
    _trackLaneScrollController.addListener(_syncHeadersToLanes);
    ref.listenManual<_PlaybackFollowState>(
      editorControllerProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          playheadSeconds: state.playheadSeconds,
          pixelsPerSecond: state.pixelsPerSecond,
        ),
      ),
      _handlePlaybackFollowState,
    );
    ref.listenManual<bool>(
      editorControllerProvider.select((state) => state.hasUnsavedChanges),
      (_, isDirty) => _beforeUnloadGuard.setDirty(isDirty),
      fireImmediately: true,
    );
    ref.listenManual<int>(
      editorControllerProvider.select((state) => state.projectRevision),
      (previous, next) {
        if (previous != null && previous != next) {
          _scheduleAutosave();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkForRecovery());
    });
  }

  @override
  void dispose() {
    _trackHeaderScrollController.removeListener(_syncLanesToHeaders);
    _trackLaneScrollController.removeListener(_syncHeadersToLanes);
    _clipDragController.dispose();
    _trackReorderController.dispose();
    _horizontalTimelineController.dispose();
    _trackHeaderScrollController.dispose();
    _trackLaneScrollController.dispose();
    _loopPreviewRegion.dispose();
    _audioMeterController.dispose();
    _autosaveTimer?.cancel();
    _beforeUnloadGuard.dispose();

    super.dispose();
  }

  void _syncLanesToHeaders() {
    _syncVerticalScroll(
      source: _trackHeaderScrollController,
      target: _trackLaneScrollController,
    );
  }

  void _syncHeadersToLanes() {
    _syncVerticalScroll(
      source: _trackLaneScrollController,
      target: _trackHeaderScrollController,
    );
  }

  void _syncVerticalScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_isSyncingVerticalScroll || !source.hasClients || !target.hasClients) {
      return;
    }

    final targetOffset = source.offset
        .clamp(target.position.minScrollExtent, target.position.maxScrollExtent)
        .toDouble();

    if ((target.offset - targetOffset).abs() < 0.5) {
      return;
    }

    _isSyncingVerticalScroll = true;
    target.jumpTo(targetOffset);
    _isSyncingVerticalScroll = false;
  }

  void _handlePlaybackFollowState(
    _PlaybackFollowState? previous,
    _PlaybackFollowState next,
  ) {
    _audioMeterController.setTransportActive(next.isPlaying);
    if (!next.isPlaying) {
      return;
    }

    final playbackStarted = previous?.isPlaying != true;
    if (playbackStarted) {
      _lastTimelineInteraction = null;
    }

    _updatePlayheadFollow(next, playbackStarted: playbackStarted);
  }

  void _updatePlayheadFollow(
    _PlaybackFollowState playback, {
    required bool playbackStarted,
  }) {
    if (_isTimelinePanning ||
        _clipDragController.isDragging ||
        !_horizontalTimelineController.hasClients) {
      return;
    }

    final viewportRenderObject = _timelineViewportKey.currentContext
        ?.findRenderObject();
    if (viewportRenderObject is! RenderBox ||
        !viewportRenderObject.hasSize ||
        viewportRenderObject.size.width <= 0) {
      return;
    }

    final now = DateTime.now();
    final lastInteraction = _lastTimelineInteraction;
    final followAllowed =
        lastInteraction == null ||
        now.difference(lastInteraction) >= _playheadFollowResumeDelay;
    final viewportWidth = viewportRenderObject.size.width;
    final scrollOffset = _horizontalTimelineController.offset;
    final transform = TimelineTransform(
      scale: TimelineScale(playback.pixelsPerSecond),
      horizontalScrollOffset: scrollOffset,
    );
    final playheadContentX = transform.timeToContentX(playback.playheadSeconds);
    final playheadViewportX = transform.timeToViewportX(
      playback.playheadSeconds,
    );
    final followThreshold = viewportWidth * _playheadFollowThresholdFraction;

    if (!followAllowed) {
      return;
    }

    final playheadIsOutsideViewport =
        playheadViewportX < 0 || playheadViewportX > viewportWidth;
    final shouldScroll = playbackStarted
        ? playheadIsOutsideViewport
        : playheadIsOutsideViewport || playheadViewportX > followThreshold;

    if (!shouldScroll) {
      return;
    }

    final targetScrollOffset = (playheadContentX - followThreshold)
        .clamp(
          _horizontalTimelineController.position.minScrollExtent,
          _horizontalTimelineController.position.maxScrollExtent,
        )
        .toDouble();

    if ((targetScrollOffset - scrollOffset).abs() < 0.5) {
      return;
    }

    _isProgrammaticTimelineScroll = true;
    try {
      _horizontalTimelineController.jumpTo(targetScrollOffset);
    } finally {
      _isProgrammaticTimelineScroll = false;
    }
  }

  void _markTimelineUserInteraction() {
    _lastTimelineInteraction = DateTime.now();
  }

  bool _handleTimelineScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) {
      return false;
    }

    final isMovement =
        notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle);

    if (!isMovement) {
      return false;
    }

    if (_isProgrammaticTimelineScroll) {
      return false;
    }

    _markTimelineUserInteraction();
    return false;
  }

  void _handleTimelineSeek(double positionSeconds) {
    _markTimelineUserInteraction();
    final tempo = ref.read(tempoControllerProvider);
    final snappedPosition = TimelineSnapper.snapTime(
      candidateSeconds: positionSeconds,
      bpm: tempo.bpm,
      timeSignature: tempo.timeSignature,
      settings: ref.read(snapControllerProvider),
    );
    ref.read(editorControllerProvider.notifier).seek(snappedPosition);
  }

  void _openCommandsDialog() {
    showCommandsDialog(context, commands: EditorCommands.all);
  }

  void _addMarkerAtPlayhead() {
    _markTimelineUserInteraction();
    ref.read(editorControllerProvider.notifier).addMarkerAtPlayhead();
  }

  void _addMarker(double timeSeconds) {
    _markTimelineUserInteraction();
    ref.read(editorControllerProvider.notifier).addMarker(timeSeconds);
  }

  void _selectMarker(String markerId) {
    _markTimelineUserInteraction();
    ref.read(editorControllerProvider.notifier).selectMarker(markerId);
  }

  void _seekToMarker(double timeSeconds) {
    _markTimelineUserInteraction();
    ref.read(editorControllerProvider.notifier).seek(timeSeconds);
  }

  void _beginMarkerMove(String markerId) {
    _markTimelineUserInteraction();
    ref.read(editorControllerProvider.notifier).beginMarkerMove(markerId);
  }

  void _deleteSelectedMarker() {
    ref.read(editorControllerProvider.notifier).deleteSelectedMarker();
  }

  void _deleteCurrentSelection() {
    final editorState = ref.read(editorControllerProvider);
    if (editorState.selectedSectionId != null) {
      ref.read(editorControllerProvider.notifier).deleteSelectedSection();
    } else if (editorState.selectedMarkerId != null) {
      _deleteSelectedMarker();
    } else {
      _deleteSelectedClip();
    }
  }

  void _openExportDialog() {
    showExportDialog(
      context,
      createTracksSnapshot: () => List<DawTrack>.unmodifiable(
        ref.read(editorControllerProvider).tracks,
      ),
      exportGenerator: ref.read(audioMixdownServiceProvider),
      onPreviewWillPlay: () {
        if (!mounted || !ref.read(editorControllerProvider).isPlaying) {
          return;
        }

        ref.read(editorControllerProvider.notifier).pause();
      },
    );
  }

  FlaudioProjectSnapshot _createProjectSnapshot({String? projectName}) {
    final editor = ref.read(editorControllerProvider);
    final tempo = ref.read(tempoControllerProvider);
    return FlaudioProjectSnapshot(
      name: projectName ?? editor.projectName,
      bpm: tempo.bpm,
      timeSignature: tempo.timeSignature,
      snapSettings: ref.read(snapControllerProvider),
      rulerMode: _rulerMode,
      isLoopEnabled: editor.isLoopEnabled,
      loopRegion: editor.loopRegion,
      masterVolumeDb: editor.masterVolumeDb,
      tracks: List<DawTrack>.unmodifiable(editor.tracks),
      markers: List.unmodifiable(editor.markers),
      sections: List.unmodifiable(editor.sections),
    );
  }

  Future<void> _saveProject() async {
    if (_isProjectOperationInProgress) {
      return;
    }
    final editor = ref.read(editorControllerProvider);
    final projectName = await showSaveProjectDialog(
      context,
      initialName: editor.projectName,
    );
    if (projectName == null || !mounted) {
      return;
    }
    final snapshot = _createProjectSnapshot(projectName: projectName);
    final io = ref.read(flaudioProjectIoServiceProvider);
    final progress = ValueNotifier(
      ProjectOperationProgress(
        title: 'Saving Project',
        status: 'Collecting audio sources...',
        projectName: projectDownloadName(snapshot.name),
      ),
    );
    var dialogVisible = false;
    setState(() => _isProjectOperationInProgress = true);
    try {
      if (snapshot.retainedAudioByteCount >= 256 * 1024) {
        dialogVisible = true;
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ProjectProgressDialog(progress: progress),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
      progress.value = ProjectOperationProgress(
        title: 'Saving Project',
        status: 'Packaging project...',
        projectName: projectDownloadName(snapshot.name),
        value: null,
      );
      if (dialogVisible) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      final bytes = io.packageProject(snapshot);
      io.downloadProject(bytes, projectName: snapshot.name);
      ref
          .read(editorControllerProvider.notifier)
          .markExplicitlySaved(projectName);
      _scheduleAutosave();
    } catch (error, stackTrace) {
      debugPrint('Save Project failed: $error\n$stackTrace');
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogVisible = false;
      }
      if (mounted) {
        await _showProjectError(
          title: 'Unable to Save Project',
          message: error is FlaudioProjectException
              ? error.userMessage
              : 'The project could not be packaged.',
        );
      }
    } finally {
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();
      if (mounted) {
        setState(() => _isProjectOperationInProgress = false);
      }
    }
  }

  Future<void> _openProject() async {
    if (_isProjectOperationInProgress) {
      return;
    }
    final io = ref.read(flaudioProjectIoServiceProvider);
    PickedFlaudioProject? picked;
    try {
      picked = await io.pickProjectFile();
    } catch (error, stackTrace) {
      debugPrint('Project picker failed: $error\n$stackTrace');
      if (mounted) {
        await _showProjectError(
          title: 'Unable to Open Project',
          message: 'The selected file could not be read.',
        );
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }
    if (ref.read(editorControllerProvider).hasUnsavedChanges) {
      final shouldContinue = await _confirmDiscardUnsavedChanges();
      if (!shouldContinue || !mounted) return;
    }

    final progress = ValueNotifier(
      ProjectOperationProgress(
        title: 'Opening Project',
        status: 'Reading project...',
        projectName: picked.name,
      ),
    );
    var dialogVisible = false;
    setState(() => _isProjectOperationInProgress = true);
    try {
      if (picked.bytes.length >= 256 * 1024) {
        dialogVisible = true;
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ProjectProgressDialog(progress: progress),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
      final document = io.readProject(picked.bytes);
      final sourceCount = document.manifest.audioSources.length;
      progress.value = ProjectOperationProgress(
        title: 'Opening Project',
        status: sourceCount == 1
            ? 'Restoring 1 audio source...'
            : 'Restoring $sourceCount audio sources...',
        projectName: document.manifest.project.name,
        value: sourceCount == 0 ? 1 : 0,
      );
      final restored = await ref
          .read(editorControllerProvider.notifier)
          .openProjectDocument(
            document,
            onSourceProgress: (completed, total) {
              progress.value = ProjectOperationProgress(
                title: 'Opening Project',
                status: total == 1
                    ? 'Restoring 1 audio source...'
                    : 'Restoring $total audio sources...',
                projectName: document.manifest.project.name,
                value: total == 0 ? 1 : completed / total,
              );
            },
          );
      if (mounted) {
        setState(() => _rulerMode = restored.rulerMode);
        _scheduleAutosave();
      }
    } catch (error, stackTrace) {
      debugPrint('Open Project failed: $error\n$stackTrace');
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogVisible = false;
      }
      if (mounted) {
        await _showProjectError(
          title: 'Unable to Open Project',
          message: error is FlaudioProjectException
              ? error.userMessage
              : 'One or more required audio sources could not be restored.',
        );
      }
    } finally {
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();
      if (mounted) {
        setState(() => _isProjectOperationInProgress = false);
      }
    }
  }

  Future<void> _showProjectError({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _performAutosave);
  }

  Future<void> _performAutosave() async {
    if (_isAutosaveWriting || !mounted) {
      _scheduleAutosave();
      return;
    }
    _isAutosaveWriting = true;
    setState(() {
      _autosaveStatus = _AutosaveStatus.saving;
      _autosaveError = null;
    });
    try {
      final document = const FlaudioProjectCodec().encodeSnapshot(
        _createProjectSnapshot(),
      );
      await ref.read(projectAutosaveStoreProvider).saveDocument(document);
      if (mounted) {
        setState(() => _autosaveStatus = _AutosaveStatus.saved);
      }
    } catch (error, stackTrace) {
      debugPrint('Autosave failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _autosaveStatus = _AutosaveStatus.failed;
          _autosaveError = error.toString();
        });
      }
    } finally {
      _isAutosaveWriting = false;
    }
  }

  Future<void> _checkForRecovery() async {
    AutosaveRecovery? recovery;
    try {
      recovery = await ref.read(projectAutosaveStoreProvider).readRecovery();
    } catch (error, stackTrace) {
      debugPrint('Recovery check failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _autosaveStatus = _AutosaveStatus.failed;
          _autosaveError = error.toString();
        });
      }
      return;
    }
    if (recovery == null || !mounted) return;

    final choice = await showProjectRecoveryDialog(context, recovery: recovery);
    if (!mounted) return;
    if (choice == ProjectRecoveryChoice.discard) {
      try {
        await ref.read(projectAutosaveStoreProvider).discardRecovery();
      } catch (error, stackTrace) {
        debugPrint('Discard recovery failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _autosaveStatus = _AutosaveStatus.failed;
            _autosaveError = error.toString();
          });
        }
      }
      return;
    }
    if (choice == ProjectRecoveryChoice.recover) {
      await _recoverProject(recovery);
    }
  }

  Future<void> _recoverProject(AutosaveRecovery recovery) async {
    final progress = ValueNotifier(
      ProjectOperationProgress(
        title: 'Recovering Project',
        status: 'Loading local audio sources...',
        projectName: recovery.manifest.project.name,
      ),
    );
    var dialogVisible = true;
    setState(() => _isProjectOperationInProgress = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProjectProgressDialog(progress: progress),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 32));
    try {
      final document = await ref
          .read(projectAutosaveStoreProvider)
          .loadDocument(recovery);
      final sourceCount = document.manifest.audioSources.length;
      final restored = await ref
          .read(editorControllerProvider.notifier)
          .openProjectDocument(
            document,
            recoveredAutosave: true,
            onSourceProgress: (completed, total) {
              progress.value = ProjectOperationProgress(
                title: 'Recovering Project',
                status: total == 1
                    ? 'Restoring audio source...'
                    : 'Restoring $total audio sources...',
                projectName: recovery.manifest.project.name,
                value: total == 0 ? 1 : completed / total,
              );
            },
          );
      if (mounted) {
        setState(() => _rulerMode = restored.rulerMode);
      }
      if (sourceCount == 0) {
        progress.value = ProjectOperationProgress(
          title: 'Recovering Project',
          status: 'Restoring project state...',
          projectName: recovery.manifest.project.name,
          value: 1,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Project recovery failed: $error\n$stackTrace');
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogVisible = false;
      }
      if (mounted) {
        final discard = await _showRecoveryFailure(error);
        if (discard) {
          try {
            await ref.read(projectAutosaveStoreProvider).discardRecovery();
          } catch (discardError, discardStackTrace) {
            debugPrint(
              'Discard broken recovery failed: '
              '$discardError\n$discardStackTrace',
            );
          }
        }
      }
    } finally {
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();
      if (mounted) {
        setState(() => _isProjectOperationInProgress = false);
      }
    }
  }

  Future<bool> _showRecoveryFailure(Object error) async {
    final message = switch (error) {
      ProjectAutosaveException(:final message) => message,
      FlaudioProjectException(:final userMessage) => userMessage,
      _ => 'The autosaved project could not be restored.',
    };
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to Recover Project'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text('$message\n\nThe current editor was not changed.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep Recovery'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard Recovery'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmDiscardUnsavedChanges() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: const Text(
                'This project has changes that have not been saved to a '
                '.flaudioproject file.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _backToMainPage() async {
    if (_isProjectOperationInProgress) return;
    if (ref.read(editorControllerProvider).hasUnsavedChanges) {
      final shouldLeave = await _confirmLeaveEditor();
      if (!shouldLeave || !mounted) return;
    }
    ref.read(editorControllerProvider.notifier).pause();
    Tooltip.dismissAllToolTips();
    if (mounted) context.goNamed(RouteNames.home);
  }

  Future<bool> _confirmLeaveEditor() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('leave-editor-dialog'),
            title: const Text('Leave Editor?'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: const Text(
                'You have changes that have not been saved to a Flaudio '
                'project file.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _splitSelectedClip() async {
    final editorState = ref.read(editorControllerProvider);
    final clipId = editorState.selectedClipId;
    if (clipId == null) {
      return;
    }

    await ref
        .read(editorControllerProvider.notifier)
        .splitClip(clipId, editorState.playheadSeconds);
  }

  Future<void> _deleteSelectedClip() async {
    await ref.read(editorControllerProvider.notifier).deleteSelectedClip();
  }

  void _copySelectedClip() {
    ref.read(editorControllerProvider.notifier).copySelectedClip();
  }

  Future<void> _pasteCopiedClip() async {
    await ref.read(editorControllerProvider.notifier).pasteCopiedClip();
  }

  Future<void> _duplicateSelectedClip() async {
    await ref.read(editorControllerProvider.notifier).duplicateSelectedClip();
  }

  Future<void> _createCrossfade() async {
    await ref.read(editorControllerProvider.notifier).createCrossfade();
  }

  Future<void> _removeCrossfade() async {
    await ref.read(editorControllerProvider.notifier).removeCrossfade();
  }

  void _undo() {
    ref.read(editorControllerProvider.notifier).undo();
  }

  void _redo() {
    ref.read(editorControllerProvider.notifier).redo();
  }

  void _addAudioTrack() {
    final trackId = ref.read(editorControllerProvider.notifier).addTrack();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final tracks = ref.read(editorControllerProvider).tracks;
      final trackIndex = tracks.indexWhere((track) => track.id == trackId);
      if (trackIndex < 0 || !_trackHeaderScrollController.hasClients) return;

      final position = _trackHeaderScrollController.position;
      final rowTop = trackIndex * trackHeight;
      final rowBottom = rowTop + trackHeight;
      var targetOffset = position.pixels;
      if (rowBottom > position.pixels + position.viewportDimension) {
        targetOffset = rowBottom - position.viewportDimension;
      } else if (rowTop < position.pixels) {
        targetOffset = rowTop;
      }
      targetOffset = targetOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((targetOffset - position.pixels).abs() < 0.5) return;

      _trackHeaderScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  List<EditorMenuSection> _buildMenuSections({
    required bool isImporting,
    required bool hasTracks,
    required bool canSplitClip,
    required bool canDeleteClip,
    required bool canCopyClip,
    required bool canPasteClip,
    required bool canDuplicateClip,
    required bool canCreateCrossfade,
    required bool canRemoveCrossfade,
    required bool canUndo,
    required bool canRedo,
    required bool canDeleteMarker,
  }) {
    return [
      EditorMenuSection(
        label: 'File',
        actions: [
          EditorMenuAction(
            label: 'Import Audio...',
            icon: Icons.library_music_outlined,
            onSelected: isImporting || _isProjectOperationInProgress
                ? null
                : _pickAudioFiles,
          ),
          EditorMenuAction(
            label: 'Open Project...',
            icon: Icons.folder_open_outlined,
            onSelected: _isProjectOperationInProgress ? null : _openProject,
          ),
          EditorMenuAction(
            label: 'Save Project...',
            icon: Icons.save_outlined,
            onSelected: _isProjectOperationInProgress ? null : _saveProject,
          ),
          EditorMenuAction(
            label: 'Export...',
            icon: Icons.download_outlined,
            onSelected:
                isImporting || _isProjectOperationInProgress || !hasTracks
                ? null
                : _openExportDialog,
          ),
          EditorMenuAction(
            label: 'Back to Main Page',
            icon: Icons.arrow_back_outlined,
            separatorBefore: true,
            onSelected: _isProjectOperationInProgress ? null : _backToMainPage,
          ),
        ],
      ),
      EditorMenuSection(
        label: 'Edit',
        actions: [
          EditorMenuAction(
            label: 'Undo',
            icon: Icons.undo,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
            ),
            onSelected: canUndo ? _undo : null,
          ),
          EditorMenuAction(
            label: 'Redo',
            icon: Icons.redo,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ),
            onSelected: canRedo ? _redo : null,
          ),
          EditorMenuAction(
            label: 'Copy',
            icon: Icons.copy_outlined,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyC,
              control: true,
            ),
            separatorBefore: true,
            onSelected: canCopyClip ? _copySelectedClip : null,
          ),
          EditorMenuAction(
            label: 'Paste',
            icon: Icons.content_paste_outlined,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyV,
              control: true,
            ),
            onSelected: canPasteClip ? _pasteCopiedClip : null,
          ),
          EditorMenuAction(
            label: 'Duplicate',
            icon: Icons.control_point_duplicate_outlined,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            onSelected: canDuplicateClip ? _duplicateSelectedClip : null,
          ),
          EditorMenuAction(
            label: 'Split Clip',
            icon: Icons.call_split_outlined,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyS),
            separatorBefore: true,
            onSelected: canSplitClip ? _splitSelectedClip : null,
          ),
          EditorMenuAction(
            label: 'Delete Clip',
            icon: Icons.delete_outline,
            shortcut: const SingleActivator(LogicalKeyboardKey.delete),
            onSelected: canDeleteClip ? _deleteSelectedClip : null,
          ),
          EditorMenuAction(
            label: 'Create Crossfade',
            icon: Icons.compare_arrows,
            separatorBefore: true,
            onSelected: canCreateCrossfade ? _createCrossfade : null,
          ),
          EditorMenuAction(
            label: 'Remove Crossfade',
            icon: Icons.close,
            onSelected: canRemoveCrossfade ? _removeCrossfade : null,
          ),
          EditorMenuAction(
            label: 'Markers',
            icon: Icons.flag_outlined,
            separatorBefore: true,
            onSelected: null,
            children: [
              EditorMenuAction(
                label: 'Add Marker at Playhead',
                icon: Icons.add_location_alt_outlined,
                onSelected: _addMarkerAtPlayhead,
              ),
              EditorMenuAction(
                label: 'Delete Selected Marker',
                icon: Icons.delete_outline,
                onSelected: canDeleteMarker ? _deleteSelectedMarker : null,
              ),
            ],
          ),
        ],
      ),
      EditorMenuSection(
        label: 'Help',
        actions: [
          EditorMenuAction(
            label: 'Commands',
            icon: Icons.keyboard_alt_outlined,
            onSelected: _openCommandsDialog,
          ),
        ],
      ),
    ];
  }

  void _handleTimelinePanZoomStart(PointerPanZoomStartEvent _) {
    _lastPanZoomScale = 1;
  }

  void _handleTimelinePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final previousScale = _lastPanZoomScale ?? 1;
    final incomingScale = event.scale;
    _lastPanZoomScale = incomingScale;
    final rawZoomFactor =
        incomingScale.isFinite &&
            incomingScale > 0 &&
            previousScale.isFinite &&
            previousScale > 0
        ? incomingScale / previousScale
        : 1.0;
    final zoomFactor = _normalizeZoomFactor(rawZoomFactor);

    if ((rawZoomFactor - 1).abs() < 0.0001) {
      if (event.panDelta.dx != 0) {
        _markTimelineUserInteraction();
      }
      return;
    }

    _markTimelineUserInteraction();
    _applyTimelineZoom(focalX: event.localPosition.dx, zoomFactor: zoomFactor);
  }

  void _handleTimelinePanZoomEnd(PointerPanZoomEndEvent _) {
    _lastPanZoomScale = null;
  }

  void _handleTimelinePointerSignal(PointerSignalEvent event) {
    final ctrlPressed = HardwareKeyboard.instance.isControlPressed;

    if (event is PointerScrollEvent) {
      if (ctrlPressed) {
        final scrollDelta = event.scrollDelta.dy != 0
            ? event.scrollDelta.dy
            : event.scrollDelta.dx;

        if (scrollDelta == 0) {
          return;
        }

        final rawZoomFactor = math.exp(-scrollDelta * 0.002);
        final zoomFactor = _normalizeZoomFactor(rawZoomFactor);

        _markTimelineUserInteraction();
        _registerPointerSignalZoom(
          event: event,
          focalX: event.localPosition.dx,
          zoomFactor: zoomFactor,
        );
        return;
      }

      if (HardwareKeyboard.instance.isShiftPressed) {
        final scrollDelta = event.scrollDelta.dy != 0
            ? event.scrollDelta.dy
            : event.scrollDelta.dx;

        if (scrollDelta != 0) {
          _registerPointerSignalHorizontalScroll(
            event: event,
            scrollDelta: scrollDelta,
          );
        }
        return;
      }

      if (event.scrollDelta.dx != 0) {
        _markTimelineUserInteraction();
      }
      return;
    }

    if (event is PointerScaleEvent) {
      final rawZoomFactor = event.scale;
      final zoomFactor = _normalizeZoomFactor(rawZoomFactor);

      if (!rawZoomFactor.isFinite || rawZoomFactor <= 0) {
        return;
      }

      if ((rawZoomFactor - 1).abs() < 0.0001) {
        return;
      }

      _markTimelineUserInteraction();
      _registerPointerSignalZoom(
        event: event,
        focalX: event.localPosition.dx,
        zoomFactor: zoomFactor,
      );
      return;
    }
  }

  void _registerPointerSignalHorizontalScroll({
    required PointerScrollEvent event,
    required double scrollDelta,
  }) {
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      resolvedEvent.respond(allowPlatformDefault: false);
      _scrollTimelineBy(scrollDelta);
    });
  }

  void _scrollTimelineBy(double delta) {
    if (!delta.isFinite ||
        delta == 0 ||
        !_horizontalTimelineController.hasClients) {
      return;
    }

    _markTimelineUserInteraction();
    _scrollTimelineTo(_horizontalTimelineController.offset + delta);
  }

  void _scrollTimelineTo(double requestedOffset) {
    if (!requestedOffset.isFinite ||
        !_horizontalTimelineController.hasClients) {
      return;
    }

    final position = _horizontalTimelineController.position;
    final targetOffset = requestedOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if ((targetOffset - _horizontalTimelineController.offset).abs() < 0.01) {
      return;
    }

    _horizontalTimelineController.jumpTo(targetOffset);
  }

  void _handleTimelinePointerDown(PointerDownEvent event) {
    if ((event.buttons & kMiddleMouseButton) == 0 ||
        !_horizontalTimelineController.hasClients) {
      return;
    }

    _timelinePanPointer = event.pointer;
    _timelinePanStartGlobalX = event.position.dx;
    _timelinePanStartScrollOffset = _horizontalTimelineController.offset;
    _markTimelineUserInteraction();

    if (!_isTimelinePanning) {
      setState(() {
        _isTimelinePanning = true;
      });
    }
  }

  void _handleTimelinePointerMove(PointerMoveEvent event) {
    if (!_isTimelinePanning || event.pointer != _timelinePanPointer) {
      return;
    }

    if ((event.buttons & kMiddleMouseButton) == 0) {
      _endTimelinePan(event.pointer);
      return;
    }

    final dragDeltaX = event.position.dx - _timelinePanStartGlobalX;
    _markTimelineUserInteraction();
    _scrollTimelineTo(_timelinePanStartScrollOffset - dragDeltaX);
  }

  void _handleTimelinePointerUp(PointerUpEvent event) {
    _endTimelinePan(event.pointer);
  }

  void _handleTimelinePointerCancel(PointerCancelEvent event) {
    _endTimelinePan(event.pointer);
  }

  void _endTimelinePan(int pointer) {
    if (!_isTimelinePanning || pointer != _timelinePanPointer) {
      return;
    }

    _timelinePanPointer = null;
    _markTimelineUserInteraction();

    if (mounted) {
      setState(() {
        _isTimelinePanning = false;
      });
    } else {
      _isTimelinePanning = false;
    }
  }

  void _registerPointerSignalZoom({
    required PointerSignalEvent event,
    required double focalX,
    required double zoomFactor,
  }) {
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      resolvedEvent.respond(allowPlatformDefault: false);

      _applyTimelineZoom(focalX: focalX, zoomFactor: zoomFactor);
    });
  }

  double _normalizeZoomFactor(double rawZoomFactor) {
    if (!rawZoomFactor.isFinite || rawZoomFactor <= 0) {
      return 1;
    }

    return rawZoomFactor.clamp(0.75, 4 / 3).toDouble();
  }

  void _applyTimelineZoom({
    required double focalX,
    required double zoomFactor,
  }) {
    final editorState = ref.read(editorControllerProvider);
    final oldPixelsPerSecond = editorState.pixelsPerSecond;
    final oldScale = TimelineScale(oldPixelsPerSecond);
    final newPixelsPerSecond = TimelineScale.clampPixelsPerSecond(
      oldPixelsPerSecond * zoomFactor,
    );
    final newScale = TimelineScale(newPixelsPerSecond);

    if (newPixelsPerSecond == oldPixelsPerSecond) {
      return;
    }

    final currentOffset =
        _pendingHorizontalOffset ??
        (_horizontalTimelineController.hasClients
            ? _horizontalTimelineController.offset
            : 0.0);
    final requestedOffset = TimelineTransform(
      scale: oldScale,
      horizontalScrollOffset: currentOffset,
    ).scrollOffsetKeepingAnchor(newScale: newScale, viewportX: focalX);

    _pendingHorizontalOffset = requestedOffset;
    ref
        .read(editorControllerProvider.notifier)
        .setPixelsPerSecond(newPixelsPerSecond);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalTimelineController.hasClients) {
        return;
      }

      final pendingOffset = _pendingHorizontalOffset;
      if (pendingOffset == null) {
        return;
      }

      final clampedOffset = pendingOffset
          .clamp(
            _horizontalTimelineController.position.minScrollExtent,
            _horizontalTimelineController.position.maxScrollExtent,
          )
          .toDouble();

      _horizontalTimelineController.jumpTo(clampedOffset);

      if (_pendingHorizontalOffset == pendingOffset) {
        _pendingHorizontalOffset = null;
      }
    });
  }

  Future<void> _pickAudioFiles() async {
    final importer = ref.read(audioImportServiceProvider);

    final result = await importer.pickAudioFiles();

    await _applyImportResult(result);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() {
      _isDraggingOverWorkspace = false;
    });

    if (ref.read(editorControllerProvider).isImporting) {
      return;
    }

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
    final bpm = ref.watch(tempoControllerProvider.select((state) => state.bpm));
    final timeSignature = ref.watch(
      tempoControllerProvider.select((state) => state.timeSignature),
    );
    final snapSettings = ref.watch(snapControllerProvider);

    final controller = ref.read(editorControllerProvider.notifier);

    return Shortcuts(
      shortcuts: const {
        EditorHistoryShortcutActivator(LogicalKeyboardKey.keyZ): UndoIntent(),
        EditorHistoryShortcutActivator(LogicalKeyboardKey.keyZ, shift: true):
            RedoIntent(),
        EditorHistoryShortcutActivator(LogicalKeyboardKey.keyY): RedoIntent(),
        EditorClipboardShortcutActivator(LogicalKeyboardKey.keyC):
            CopyClipIntent(),
        EditorClipboardShortcutActivator(LogicalKeyboardKey.keyV):
            PasteClipIntent(),
        EditorClipboardShortcutActivator(LogicalKeyboardKey.keyD):
            DuplicateClipIntent(),
        EditorCommandShortcutActivator(LogicalKeyboardKey.keyS):
            SplitClipIntent(),
        EditorCommandShortcutActivator(LogicalKeyboardKey.delete):
            DeleteClipIntent(),
        EditorCommandShortcutActivator(LogicalKeyboardKey.backspace):
            DeleteClipIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearClipSelectionIntent(),
        PlayPauseShortcutActivator(): PlayPauseIntent(),
        EditorCommandShortcutActivator(LogicalKeyboardKey.keyL):
            ToggleLoopIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _undo();
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _redo();
              }
              return null;
            },
          ),
          CopyClipIntent: CallbackAction<CopyClipIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _copySelectedClip();
              }
              return null;
            },
          ),
          PasteClipIntent: CallbackAction<PasteClipIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _pasteCopiedClip();
              }
              return null;
            },
          ),
          DuplicateClipIntent: CallbackAction<DuplicateClipIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _duplicateSelectedClip();
              }
              return null;
            },
          ),
          SplitClipIntent: CallbackAction<SplitClipIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _splitSelectedClip();
              }
              return null;
            },
          ),
          DeleteClipIntent: CallbackAction<DeleteClipIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                _deleteCurrentSelection();
              }
              return null;
            },
          ),
          _ClearClipSelectionIntent: CallbackAction<_ClearClipSelectionIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                controller.clearClipSelection();
                controller.clearMarkerSelection();
                controller.clearSectionSelection();
              }
              return null;
            },
          ),
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleTransportShortcut(context)) {
                controller.togglePlayback();
              }
              return null;
            },
          ),
          ToggleLoopIntent: CallbackAction<ToggleLoopIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleTransportShortcut(context)) {
                controller.toggleLoop();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Column(
              children: [
                EditorMenuBar(
                  trailing: _AutosaveStatusView(
                    status: _autosaveStatus,
                    error: _autosaveError,
                  ),
                  sections: _buildMenuSections(
                    isImporting: editorState.isImporting,
                    hasTracks: editorState.tracks.isNotEmpty,
                    canSplitClip: editorState.canSplitSelectedClip,
                    canDeleteClip: editorState.canDeleteSelectedClip,
                    canCopyClip: editorState.canCopySelectedClip,
                    canPasteClip: editorState.canPasteClip,
                    canDuplicateClip: editorState.canDuplicateSelectedClip,
                    canCreateCrossfade: editorState.canCreateCrossfade,
                    canRemoveCrossfade: editorState.canRemoveCrossfade,
                    canUndo: editorState.canUndo,
                    canRedo: editorState.canRedo,
                    canDeleteMarker: editorState.selectedMarkerId != null,
                  ),
                ),

                TransportBar(
                  isPlaying: editorState.isPlaying,
                  isImporting: editorState.isImporting,
                  isLoopEnabled: editorState.isLoopEnabled,
                  positionSeconds: editorState.playheadSeconds,
                  masterVolumeDb: editorState.masterVolumeDb,
                  rulerMode: _rulerMode,
                  meterController: _audioMeterController,
                  onPlayPressed: controller.togglePlayback,
                  onStopPressed: controller.stop,
                  onLoopPressed: controller.toggleLoop,
                  onMasterVolumeChangeStart: controller.beginMasterVolumeChange,
                  onMasterVolumeChanged: controller.previewMasterVolume,
                  onMasterVolumeChangeEnd: controller.commitMasterVolumeChange,
                  onMasterVolumeReset: controller.resetMasterVolume,
                  onRulerModeChanged: (mode) {
                    if (mode != _rulerMode) {
                      setState(() => _rulerMode = mode);
                      controller.markPersistentSettingsChanged();
                    }
                  },
                ),

                Expanded(
                  child: DropTarget(
                    enable:
                        !editorState.isImporting &&
                        !_isProjectOperationInProgress,
                    onDragEntered: (_) {
                      if (!_isDraggingOverWorkspace) {
                        setState(() {
                          _isDraggingOverWorkspace = true;
                        });
                      }
                    },
                    onDragExited: (_) {
                      if (_isDraggingOverWorkspace) {
                        setState(() {
                          _isDraggingOverWorkspace = false;
                        });
                      }
                    },
                    onDragDone: _handleDrop,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportWidth = math.max(
                                0.0,
                                constraints.maxWidth - trackHeaderWidth,
                              );
                              final scale = TimelineScale(
                                editorState.pixelsPerSecond,
                              );
                              final gridMetrics = TimelineGridMetrics(
                                transform: TimelineTransform(scale: scale),
                              );
                              return Row(
                                children: [
                                  SizedBox(
                                    width: trackHeaderWidth,
                                    child: Column(
                                      children: [
                                        _TrackHeaderCorner(
                                          onAddPressed: _addAudioTrack,
                                        ),
                                        Expanded(
                                          child: TrackHeaderList(
                                            scrollController:
                                                _trackHeaderScrollController,
                                            meterController:
                                                _audioMeterController,
                                            reorderController:
                                                _trackReorderController,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: NotificationListener<ScrollNotification>(
                                      onNotification:
                                          _handleTimelineScrollNotification,
                                      child: Scrollbar(
                                        controller:
                                            _horizontalTimelineController,
                                        thumbVisibility: true,
                                        notificationPredicate: (notification) {
                                          return notification.metrics.axis ==
                                              Axis.horizontal;
                                        },
                                        child: MouseRegion(
                                          cursor: _isTimelinePanning
                                              ? SystemMouseCursors.grabbing
                                              : MouseCursor.defer,
                                          child: Listener(
                                            key: _timelineViewportKey,
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onPointerDown:
                                                _handleTimelinePointerDown,
                                            onPointerMove:
                                                _handleTimelinePointerMove,
                                            onPointerUp:
                                                _handleTimelinePointerUp,
                                            onPointerCancel:
                                                _handleTimelinePointerCancel,
                                            onPointerSignal:
                                                _handleTimelinePointerSignal,
                                            onPointerPanZoomStart:
                                                _handleTimelinePanZoomStart,
                                            onPointerPanZoomUpdate:
                                                _handleTimelinePanZoomUpdate,
                                            onPointerPanZoomEnd:
                                                _handleTimelinePanZoomEnd,
                                            child: SingleChildScrollView(
                                              controller:
                                                  _horizontalTimelineController,
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const _ControlReservedScrollPhysics(),
                                              child: ValueListenableBuilder<TimelineClipDragState?>(
                                                valueListenable:
                                                    _clipDragController,
                                                builder: (context, dragState, _) {
                                                  final previewDuration = math.max(
                                                    editorState
                                                        .timelineDurationSeconds,
                                                    dragState
                                                            ?.previewEndSeconds ??
                                                        0.0,
                                                  );
                                                  final contentWidth = scale
                                                      .timelineContentWidth(
                                                        durationSeconds:
                                                            previewDuration,
                                                        viewportWidth:
                                                            viewportWidth,
                                                      );

                                                  return SizedBox(
                                                    width: contentWidth,
                                                    height:
                                                        constraints.maxHeight,
                                                    child: ValueListenableBuilder<LoopRegion?>(
                                                      valueListenable:
                                                          _loopPreviewRegion,
                                                      child: TimelineTrackList(
                                                        viewportKey:
                                                            _trackLaneViewportKey,
                                                        scrollController:
                                                            _trackLaneScrollController,
                                                        gridMetrics:
                                                            gridMetrics,
                                                        clipDragController:
                                                            _clipDragController,
                                                        reorderController:
                                                            _trackReorderController,
                                                        scrollPhysics:
                                                            const _ControlReservedScrollPhysics(),
                                                        onSeek:
                                                            _handleTimelineSeek,
                                                      ),
                                                      builder:
                                                          (
                                                            context,
                                                            draftRegion,
                                                            trackList,
                                                          ) {
                                                            final effectiveLoopRegion =
                                                                draftRegion ??
                                                                editorState
                                                                    .loopRegion;
                                                            return Column(
                                                              children: [
                                                                TimelineRuler(
                                                                  playheadSeconds:
                                                                      editorState
                                                                          .playheadSeconds,
                                                                  gridMetrics:
                                                                      gridMetrics,
                                                                  mode:
                                                                      _rulerMode,
                                                                  bpm: bpm,
                                                                  timeSignature:
                                                                      timeSignature,
                                                                  loopRegion:
                                                                      effectiveLoopRegion,
                                                                  isLoopEnabled:
                                                                      editorState
                                                                          .isLoopEnabled,
                                                                  snapSettings:
                                                                      snapSettings,
                                                                  markers:
                                                                      editorState
                                                                          .markers,
                                                                  sections:
                                                                      editorState
                                                                          .sections,
                                                                  selectedMarkerId:
                                                                      editorState
                                                                          .selectedMarkerId,
                                                                  selectedSectionId:
                                                                      editorState
                                                                          .selectedSectionId,
                                                                  onAddMarker:
                                                                      _addMarker,
                                                                  onSelectMarker:
                                                                      _selectMarker,
                                                                  onMarkerSeek:
                                                                      _seekToMarker,
                                                                  onMarkerMoveStart:
                                                                      _beginMarkerMove,
                                                                  onMarkerMovePreview:
                                                                      controller
                                                                          .previewMarkerMove,
                                                                  onMarkerMoveEnd:
                                                                      controller
                                                                          .commitMarkerMove,
                                                                  onMarkerMoveCancel:
                                                                      controller
                                                                          .cancelMarkerMove,
                                                                  onMarkerRename:
                                                                      controller
                                                                          .renameMarker,
                                                                  onMarkerColorSelected:
                                                                      controller
                                                                          .changeMarkerColor,
                                                                  onMarkerDelete:
                                                                      controller
                                                                          .deleteMarker,
                                                                  onAddSection:
                                                                      controller
                                                                          .addSection,
                                                                  onSelectSection:
                                                                      controller
                                                                          .selectSection,
                                                                  onSectionEditStart:
                                                                      controller
                                                                          .beginSectionEdit,
                                                                  onSectionMovePreview:
                                                                      controller
                                                                          .previewSectionMove,
                                                                  onSectionStartResizePreview:
                                                                      controller
                                                                          .previewSectionStartResize,
                                                                  onSectionEndResizePreview:
                                                                      controller
                                                                          .previewSectionEndResize,
                                                                  onSectionEditEnd:
                                                                      (
                                                                        sectionId,
                                                                        isResize,
                                                                      ) => controller.commitSectionEdit(
                                                                        sectionId,
                                                                        isResize:
                                                                            isResize,
                                                                      ),
                                                                  onSectionEditCancel:
                                                                      controller
                                                                          .cancelSectionEdit,
                                                                  onSectionRename:
                                                                      controller
                                                                          .renameSection,
                                                                  onSectionColorSelected:
                                                                      controller
                                                                          .changeSectionColor,
                                                                  onSectionDelete:
                                                                      controller
                                                                          .deleteSection,
                                                                  onEmptySectionLaneTap:
                                                                      controller
                                                                          .clearSectionSelection,
                                                                  onLoopRegionPreviewChanged:
                                                                      (
                                                                        region,
                                                                      ) => _loopPreviewRegion.value =
                                                                          region,
                                                                  onLoopRegionChanged:
                                                                      controller
                                                                          .setLoopRegion,
                                                                  onSeek:
                                                                      _handleTimelineSeek,
                                                                ),
                                                                Expanded(
                                                                  child: TimelineLoopOverlay(
                                                                    gridMetrics:
                                                                        gridMetrics,
                                                                    playheadSeconds:
                                                                        editorState
                                                                            .playheadSeconds,
                                                                    loopRegion:
                                                                        effectiveLoopRegion,
                                                                    isLoopEnabled:
                                                                        editorState
                                                                            .isLoopEnabled,
                                                                    bpm: bpm,
                                                                    timeSignature:
                                                                        timeSignature,
                                                                    snapSettings:
                                                                        snapSettings,
                                                                    rulerMode:
                                                                        _rulerMode,
                                                                    verticalScrollController:
                                                                        _trackLaneScrollController,
                                                                    markers:
                                                                        editorState
                                                                            .markers,
                                                                    sections:
                                                                        editorState
                                                                            .sections,
                                                                    selectedMarkerId:
                                                                        editorState
                                                                            .selectedMarkerId,
                                                                    selectedSectionId:
                                                                        editorState
                                                                            .selectedSectionId,
                                                                    child:
                                                                        trackList!,
                                                                  ),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _isDraggingOverWorkspace ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: const _DropOverlay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AutosaveStatus { idle, saving, saved, failed }

class _AutosaveStatusView extends StatelessWidget {
  const _AutosaveStatusView({required this.status, this.error});

  final _AutosaveStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (status == _AutosaveStatus.idle) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (status) {
      _AutosaveStatus.saving => (
        Icons.sync,
        'Saving...',
        colors.onSurfaceVariant,
      ),
      _AutosaveStatus.saved => (
        Icons.check_circle_outline,
        'Saved locally',
        colors.onSurfaceVariant,
      ),
      _AutosaveStatus.failed => (
        Icons.error_outline,
        'Autosave failed',
        colors.error,
      ),
      _AutosaveStatus.idle => (Icons.check, '', colors.onSurfaceVariant),
    };
    return Tooltip(
      message: status == _AutosaveStatus.failed
          ? (error ?? 'Browser-local autosave failed.')
          : label,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlReservedScrollPhysics extends ScrollPhysics {
  const _ControlReservedScrollPhysics({super.parent});

  @override
  _ControlReservedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ControlReservedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (HardwareKeyboard.instance.isControlPressed) {
      return false;
    }

    return super.shouldAcceptUserOffset(position);
  }
}

class _TrackHeaderCorner extends StatelessWidget {
  const _TrackHeaderCorner({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: trackHeaderWidth,
      height: TimelineRuler.height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'TRACKS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('add-audio-track-button'),
              tooltip: 'Add audio track',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
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
