import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../application/editor_controller.dart';
import '../application/snap_controller.dart';
import '../application/tempo_controller.dart';
import '../domain/daw_track.dart';
import '../domain/loop_region.dart';
import '../domain/timeline_scale.dart';
import '../domain/timeline_snapper.dart';
import '../infrastructure/audio_import_service.dart';
import '../infrastructure/audio_mixdown_service.dart';
import 'controllers/timeline_clip_drag_controller.dart';
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
  bool _isSyncingVerticalScroll = false;
  bool _isProgrammaticTimelineScroll = false;
  bool _isTimelinePanning = false;
  int? _timelinePanPointer;
  double _timelinePanStartGlobalX = 0;
  double _timelinePanStartScrollOffset = 0;
  double? _pendingHorizontalOffset;
  double? _lastPanZoomScale;
  DateTime? _lastTimelineInteraction;
  TimelineRulerMode _rulerMode = TimelineRulerMode.barsBeats;

  final GlobalKey _timelineViewportKey = GlobalKey();

  late final ScrollController _horizontalTimelineController;
  late final ScrollController _trackHeaderScrollController;
  late final ScrollController _trackLaneScrollController;
  late final TimelineClipDragController _clipDragController;
  late final ValueNotifier<LoopRegion?> _loopPreviewRegion;

  @override
  void initState() {
    super.initState();

    _horizontalTimelineController = ScrollController();
    _trackHeaderScrollController = ScrollController();
    _trackLaneScrollController = ScrollController();
    _loopPreviewRegion = ValueNotifier<LoopRegion?>(null);
    _clipDragController = TimelineClipDragController(
      _horizontalTimelineController,
      _timelineViewportKey,
      _markTimelineUserInteraction,
    );

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
  }

  @override
  void dispose() {
    _trackHeaderScrollController.removeListener(_syncLanesToHeaders);
    _trackLaneScrollController.removeListener(_syncHeadersToLanes);
    _clipDragController.dispose();
    _horizontalTimelineController.dispose();
    _trackHeaderScrollController.dispose();
    _trackLaneScrollController.dispose();
    _loopPreviewRegion.dispose();

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
    final snappedPosition = TimelineSnapper.snapTime(
      candidateSeconds: positionSeconds,
      bpm: ref.read(tempoControllerProvider).bpm,
      settings: ref.read(snapControllerProvider),
    );
    ref.read(editorControllerProvider.notifier).seek(snappedPosition);
  }

  void _openCommandsDialog() {
    showCommandsDialog(context, commands: EditorCommands.all);
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

  void _undo() {
    ref.read(editorControllerProvider.notifier).undo();
  }

  void _redo() {
    ref.read(editorControllerProvider.notifier).redo();
  }

  List<EditorMenuSection> _buildMenuSections({
    required bool isImporting,
    required bool hasTracks,
    required bool canSplitClip,
    required bool canDeleteClip,
    required bool canCopyClip,
    required bool canPasteClip,
    required bool canDuplicateClip,
    required bool canUndo,
    required bool canRedo,
  }) {
    return [
      EditorMenuSection(
        label: 'File',
        actions: [
          EditorMenuAction(
            label: 'Import Audio...',
            icon: Icons.library_music_outlined,
            onSelected: isImporting ? null : _pickAudioFiles,
          ),
          EditorMenuAction(
            label: 'Export...',
            icon: Icons.download_outlined,
            separatorBefore: true,
            onSelected: isImporting || !hasTracks ? null : _openExportDialog,
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
                _deleteSelectedClip();
              }
              return null;
            },
          ),
          _ClearClipSelectionIntent: CallbackAction<_ClearClipSelectionIntent>(
            onInvoke: (_) {
              if (EditorShortcutPolicy.canHandleEditorCommand(context)) {
                controller.clearClipSelection();
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
                  sections: _buildMenuSections(
                    isImporting: editorState.isImporting,
                    hasTracks: editorState.tracks.isNotEmpty,
                    canSplitClip: editorState.canSplitSelectedClip,
                    canDeleteClip: editorState.canDeleteSelectedClip,
                    canCopyClip: editorState.canCopySelectedClip,
                    canPasteClip: editorState.canPasteClip,
                    canDuplicateClip: editorState.canDuplicateSelectedClip,
                    canUndo: editorState.canUndo,
                    canRedo: editorState.canRedo,
                  ),
                ),

                TransportBar(
                  isPlaying: editorState.isPlaying,
                  isImporting: editorState.isImporting,
                  isLoopEnabled: editorState.isLoopEnabled,
                  positionSeconds: editorState.playheadSeconds,
                  rulerMode: _rulerMode,
                  onPlayPressed: controller.togglePlayback,
                  onStopPressed: controller.stop,
                  onLoopPressed: controller.toggleLoop,
                  onRulerModeChanged: (mode) {
                    if (mode != _rulerMode) {
                      setState(() => _rulerMode = mode);
                    }
                  },
                ),

                Expanded(
                  child: DropTarget(
                    enable: !editorState.isImporting,
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
                                        const _TrackHeaderCorner(),
                                        Expanded(
                                          child: TrackHeaderList(
                                            scrollController:
                                                _trackHeaderScrollController,
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
                                                        scrollController:
                                                            _trackLaneScrollController,
                                                        gridMetrics:
                                                            gridMetrics,
                                                        clipDragController:
                                                            _clipDragController,
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
                                                                  loopRegion:
                                                                      effectiveLoopRegion,
                                                                  isLoopEnabled:
                                                                      editorState
                                                                          .isLoopEnabled,
                                                                  snapSettings:
                                                                      snapSettings,
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
                                                                    snapSettings:
                                                                        snapSettings,
                                                                    rulerMode:
                                                                        _rulerMode,
                                                                    verticalScrollController:
                                                                        _trackLaneScrollController,
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
  const _TrackHeaderCorner();

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
