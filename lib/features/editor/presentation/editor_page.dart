import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../application/editor_controller.dart';
import '../domain/timeline_scale.dart';
import '../infrastructure/audio_import_service.dart';
import 'widgets/track_header.dart';
import 'widgets/track_list.dart';
import 'widgets/timeline_ruler.dart';
import 'widgets/transport_bar.dart';

typedef _PlaybackFollowState = ({
  bool isPlaying,
  double playheadSeconds,
  double pixelsPerSecond,
});

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const _playheadFollowResumeDelay = Duration(seconds: 3);
  static const _playheadFollowThresholdFraction = 0.75;
  static const _followDebugThrottle = Duration(milliseconds: 500);

  bool _isDragging = false;
  bool _isSyncingVerticalScroll = false;
  bool _isPointerInsideTimelineViewport = false;
  bool _isProgrammaticTimelineScroll = false;
  bool _isPlayheadFollowSuspended = false;
  double? _pendingHorizontalOffset;
  double? _lastPanZoomScale;
  DateTime? _lastTimelineInteraction;
  DateTime? _lastFollowStatusLog;
  DateTime? _lastFollowScrollLog;

  final GlobalKey _timelineViewportKey = GlobalKey(
    debugLabel: 'timeline-viewport',
  );

  late final ScrollController _horizontalTimelineController;
  late final ScrollController _trackHeaderScrollController;
  late final ScrollController _trackLaneScrollController;

  @override
  void initState() {
    super.initState();

    _horizontalTimelineController = ScrollController();
    _trackHeaderScrollController = ScrollController();
    _trackLaneScrollController = ScrollController();

    _trackHeaderScrollController.addListener(_syncLanesToHeaders);
    _trackLaneScrollController.addListener(_syncHeadersToLanes);
    HardwareKeyboard.instance.addHandler(_handleKeyboardDiagnostic);
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
    HardwareKeyboard.instance.removeHandler(_handleKeyboardDiagnostic);
    _horizontalTimelineController.dispose();
    _trackHeaderScrollController.dispose();
    _trackLaneScrollController.dispose();

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
      if (previous?.isPlaying == true) {
        _timelineFollowDebug(
          'follow-stopped reason=playback-not-running '
          'playback=${next.playheadSeconds.toStringAsFixed(3)}s',
        );
      }
      return;
    }

    final playbackStarted = previous?.isPlaying != true;
    if (playbackStarted) {
      _lastTimelineInteraction = null;
      _isPlayheadFollowSuspended = false;
      _timelineFollowDebug(
        'follow-started reason=playback-start '
        'playback=${next.playheadSeconds.toStringAsFixed(3)}s',
      );
    }

    _updatePlayheadFollow(next, playbackStarted: playbackStarted);
  }

  void _updatePlayheadFollow(
    _PlaybackFollowState playback, {
    required bool playbackStarted,
  }) {
    if (!_horizontalTimelineController.hasClients) {
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
    final playheadContentX = TimelineScale(
      playback.pixelsPerSecond,
    ).secondsToPixels(playback.playheadSeconds);
    final playheadViewportX = playheadContentX - scrollOffset;
    final followThreshold = viewportWidth * _playheadFollowThresholdFraction;

    _logFollowStatusThrottled(
      now: now,
      playback: playback,
      playheadContentX: playheadContentX,
      playheadViewportX: playheadViewportX,
      viewportWidth: viewportWidth,
      scrollOffset: scrollOffset,
      followThreshold: followThreshold,
      followAllowed: followAllowed,
    );

    if (!followAllowed) {
      return;
    }

    if (_isPlayheadFollowSuspended) {
      _isPlayheadFollowSuspended = false;
      _timelineFollowDebug('follow-resumed reason=idle-timeout');
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

    _logFollowScrollThrottled(
      now: now,
      currentOffset: scrollOffset,
      targetOffset: targetScrollOffset,
    );

    _isProgrammaticTimelineScroll = true;
    try {
      _horizontalTimelineController.jumpTo(targetScrollOffset);
    } finally {
      _isProgrammaticTimelineScroll = false;
    }
  }

  void _markTimelineUserInteraction(String reason) {
    _lastTimelineInteraction = DateTime.now();

    if (_isPlayheadFollowSuspended) {
      return;
    }

    _isPlayheadFollowSuspended = true;
    _timelineFollowDebug(
      'follow-suspended reason=$reason initiator=user '
      'resumeAfter=${_playheadFollowResumeDelay.inSeconds}s',
    );
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

    _markTimelineUserInteraction('user-scroll');
    return false;
  }

  void _handleTimelineSeek(double positionSeconds) {
    _markTimelineUserInteraction('timeline-seek');
    ref.read(editorControllerProvider.notifier).seek(positionSeconds);
  }

  void _logFollowStatusThrottled({
    required DateTime now,
    required _PlaybackFollowState playback,
    required double playheadContentX,
    required double playheadViewportX,
    required double viewportWidth,
    required double scrollOffset,
    required double followThreshold,
    required bool followAllowed,
  }) {
    final lastLog = _lastFollowStatusLog;
    if (lastLog != null && now.difference(lastLog) < _followDebugThrottle) {
      return;
    }

    _lastFollowStatusLog = now;
    final reason = followAllowed ? 'active' : 'recent-user-interaction';
    _timelineFollowDebug(
      'playback=${playback.playheadSeconds.toStringAsFixed(3)}s '
      'playheadX=${playheadContentX.toStringAsFixed(1)} '
      'viewportX=${playheadViewportX.toStringAsFixed(1)} '
      'viewportWidth=${viewportWidth.toStringAsFixed(1)} '
      'scrollOffset=${scrollOffset.toStringAsFixed(1)} '
      'threshold=${followThreshold.toStringAsFixed(1)} '
      'follow=$followAllowed reason=$reason',
    );
  }

  void _logFollowScrollThrottled({
    required DateTime now,
    required double currentOffset,
    required double targetOffset,
  }) {
    final lastLog = _lastFollowScrollLog;
    if (lastLog != null && now.difference(lastLog) < _followDebugThrottle) {
      return;
    }

    _lastFollowScrollLog = now;
    _timelineFollowDebug(
      'auto-scroll current=${currentOffset.toStringAsFixed(1)} '
      'target=${targetOffset.toStringAsFixed(1)} initiator=programmatic',
    );
  }

  void _timelineFollowDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TimelineFollowDebug] $message');
    }
  }

  // TEMPORARY: timeline input diagnostics. These logs do not consume input.
  bool _handleKeyboardDiagnostic(KeyEvent event) {
    final logicalKey = event.logicalKey;
    final isControlKey =
        logicalKey == LogicalKeyboardKey.controlLeft ||
        logicalKey == LogicalKeyboardKey.controlRight ||
        logicalKey == LogicalKeyboardKey.control;

    if (isControlKey) {
      _timelineDebug(
        'keyboard ${event.runtimeType} '
        'key=${logicalKey.debugName} '
        'ctrl=${HardwareKeyboard.instance.isControlPressed} '
        'focus=${FocusManager.instance.primaryFocus?.debugLabel ?? 'none'}',
      );
    }

    return false;
  }

  void _handleTimelinePointerEnter(PointerEnterEvent event) {
    _isPointerInsideTimelineViewport = true;
    _timelineDebug(
      'viewport PointerEnterEvent '
      'local=${event.localPosition} global=${event.position} '
      'inside=${_isInsideTimelineViewport(event.position)}',
    );
  }

  void _handleTimelinePointerExit(PointerExitEvent event) {
    _isPointerInsideTimelineViewport = false;
    _timelineDebug(
      'viewport PointerExitEvent '
      'local=${event.localPosition} global=${event.position} '
      'inside=${_isInsideTimelineViewport(event.position)}',
    );
  }

  void _handleTimelinePanZoomStart(PointerPanZoomStartEvent event) {
    _lastPanZoomScale = 1;
    _timelineDebug(
      'viewport PointerPanZoomStartEvent '
      'ctrl=${HardwareKeyboard.instance.isControlPressed} '
      'focalPoint=${event.localPosition} '
      'local=${event.localPosition} global=${event.position} '
      'inside=${_isInsideTimelineViewport(event.position)} '
      'trackedInside=$_isPointerInsideTimelineViewport '
      'kind=${event.kind.name} device=${event.device}',
    );
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

    _timelineDebug(
      'viewport PointerPanZoomUpdateEvent '
      'ctrl=${HardwareKeyboard.instance.isControlPressed} '
      'pan=${event.pan} localPan=${event.localPan} '
      'panDelta=${event.panDelta} localPanDelta=${event.localPanDelta} '
      'scale=$incomingScale previousScale=$previousScale '
      'rawZoomFactor=$rawZoomFactor zoomFactor=$zoomFactor '
      'focalPoint=${event.localPosition} rotation=${event.rotation} '
      'local=${event.localPosition} global=${event.position} '
      'inside=${_isInsideTimelineViewport(event.position)} '
      'trackedInside=$_isPointerInsideTimelineViewport '
      'kind=${event.kind.name} device=${event.device}',
    );

    if ((rawZoomFactor - 1).abs() < 0.0001) {
      if (event.panDelta.dx != 0) {
        _markTimelineUserInteraction('trackpad-pan');
      }
      _timelineDebug(
        'pan-zoom ignored reason=pan-only scale=$incomingScale '
        'panDelta=${event.panDelta}',
      );
      return;
    }

    _markTimelineUserInteraction('pinch-zoom');
    _applyTimelineZoom(
      focalX: event.localPosition.dx,
      zoomFactor: zoomFactor,
      source: 'PointerPanZoomUpdateEvent',
    );
  }

  void _handleTimelinePanZoomEnd(PointerPanZoomEndEvent event) {
    _timelineDebug(
      'viewport PointerPanZoomEndEvent '
      'ctrl=${HardwareKeyboard.instance.isControlPressed} '
      'lastScale=$_lastPanZoomScale focalPoint=${event.localPosition} '
      'local=${event.localPosition} global=${event.position} '
      'inside=${_isInsideTimelineViewport(event.position)} '
      'trackedInside=$_isPointerInsideTimelineViewport '
      'kind=${event.kind.name} device=${event.device}',
    );
    _lastPanZoomScale = null;
  }

  bool _isInsideTimelineViewport(Offset globalPosition) {
    final renderObject = _timelineViewportKey.currentContext
        ?.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }

    final viewportPosition = renderObject.globalToLocal(globalPosition);
    return (Offset.zero & renderObject.size).contains(viewportPosition);
  }

  void _timelineDebug(String message) {
    if (kDebugMode) {
      debugPrint('[TimelineZoomDebug] $message');
    }
  }

  void _handleTimelinePointerSignal(PointerSignalEvent event) {
    final ctrlPressed = HardwareKeyboard.instance.isControlPressed;
    final inside = _isInsideTimelineViewport(event.position);

    if (event is PointerScrollEvent) {
      _timelineDebug(
        'viewport PointerScrollEvent '
        'ctrl=$ctrlPressed scrollDelta=${event.scrollDelta} '
        'focalPoint=${event.localPosition} '
        'local=${event.localPosition} global=${event.position} '
        'inside=$inside trackedInside=$_isPointerInsideTimelineViewport '
        'kind=${event.kind.name} device=${event.device}',
      );

      if (!ctrlPressed) {
        if (event.scrollDelta.dx != 0 ||
            (HardwareKeyboard.instance.isShiftPressed &&
                event.scrollDelta.dy != 0)) {
          _markTimelineUserInteraction('horizontal-scroll');
        }
        _timelineDebug(
          'zoom-handler ignored reason=ctrl-not-pressed '
          'scrollDelta=${event.scrollDelta}',
        );
        return;
      }

      final scrollDelta = event.scrollDelta.dy != 0
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;

      if (scrollDelta == 0) {
        _timelineDebug(
          'zoom-handler ignored reason=zero-scroll-delta '
          'scrollDelta=${event.scrollDelta}',
        );
        return;
      }

      final rawZoomFactor = math.exp(-scrollDelta * 0.002);
      final zoomFactor = _normalizeZoomFactor(rawZoomFactor);

      _markTimelineUserInteraction('ctrl-wheel-zoom');
      _registerPointerSignalZoom(
        event: event,
        focalX: event.localPosition.dx,
        rawZoomFactor: rawZoomFactor,
        zoomFactor: zoomFactor,
        source: 'PointerScrollEvent',
        input: 'scrollDelta=${event.scrollDelta}',
      );
      return;
    }

    if (event is PointerScaleEvent) {
      final rawZoomFactor = event.scale;
      final zoomFactor = _normalizeZoomFactor(rawZoomFactor);

      _timelineDebug(
        'viewport PointerScaleEvent runtimeType=${event.runtimeType} '
        'ctrl=$ctrlPressed incomingScale=${event.scale} '
        'rawZoomFactor=$rawZoomFactor zoomFactor=$zoomFactor '
        'focalPoint=${event.localPosition} '
        'local=${event.localPosition} global=${event.position} '
        'inside=$inside trackedInside=$_isPointerInsideTimelineViewport '
        'kind=${event.kind.name} device=${event.device}',
      );

      if (!rawZoomFactor.isFinite || rawZoomFactor <= 0) {
        _timelineDebug(
          'zoom-handler ignored reason=invalid-pointer-scale '
          'incomingScale=${event.scale}',
        );
        return;
      }

      if ((rawZoomFactor - 1).abs() < 0.0001) {
        _timelineDebug(
          'zoom-handler ignored reason=unchanged-pointer-scale '
          'incomingScale=${event.scale}',
        );
        return;
      }

      _markTimelineUserInteraction('pointer-scale-zoom');
      _registerPointerSignalZoom(
        event: event,
        focalX: event.localPosition.dx,
        rawZoomFactor: rawZoomFactor,
        zoomFactor: zoomFactor,
        source: 'PointerScaleEvent',
        input: 'incomingScale=${event.scale}',
      );
      return;
    }

    _timelineDebug(
      'viewport ${event.runtimeType} ctrl=$ctrlPressed '
      'local=${event.localPosition} global=${event.position} '
      'inside=$inside trackedInside=$_isPointerInsideTimelineViewport '
      'kind=${event.kind.name} device=${event.device}',
    );
    _timelineDebug('zoom-handler ignored reason=unsupported-pointer-signal');
  }

  void _registerPointerSignalZoom({
    required PointerSignalEvent event,
    required double focalX,
    required double rawZoomFactor,
    required double zoomFactor,
    required String source,
    required String input,
  }) {
    _timelineDebug(
      'zoom-handler resolver-register source=$source $input '
      'focalPointX=$focalX rawZoomFactor=$rawZoomFactor '
      'zoomFactor=$zoomFactor',
    );

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      resolvedEvent.respond(allowPlatformDefault: false);
      _timelineDebug(
        'zoom-handler resolver-won source=$source '
        'focalPointX=$focalX zoomFactor=$zoomFactor',
      );

      _applyTimelineZoom(
        focalX: focalX,
        zoomFactor: zoomFactor,
        source: source,
      );
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
    required String source,
  }) {
    final editorState = ref.read(editorControllerProvider);
    final oldPixelsPerSecond = editorState.pixelsPerSecond;
    final oldScale = TimelineScale(oldPixelsPerSecond);
    final newPixelsPerSecond = TimelineScale.clampPixelsPerSecond(
      oldPixelsPerSecond * zoomFactor,
    );
    final newScale = TimelineScale(newPixelsPerSecond);

    if (newPixelsPerSecond == oldPixelsPerSecond) {
      _timelineDebug(
        'zoom-calculation unchanged source=$source '
        'oldPps=$oldPixelsPerSecond '
        'requestedPps=${oldPixelsPerSecond * zoomFactor} '
        'clampedPps=$newPixelsPerSecond',
      );
      return;
    }

    final currentOffset =
        _pendingHorizontalOffset ??
        (_horizontalTimelineController.hasClients
            ? _horizontalTimelineController.offset
            : 0.0);
    final requestedOffset = oldScale.scrollOffsetKeepingAnchor(
      newScale: newScale,
      currentScrollOffset: currentOffset,
      viewportX: focalX,
    );

    _timelineDebug(
      'zoom-calculation source=$source oldPps=$oldPixelsPerSecond '
      'newPps=$newPixelsPerSecond zoomFactor=$zoomFactor '
      'focalPointX=$focalX currentOffset=$currentOffset '
      'requestedOffset=$requestedOffset',
    );

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

      _timelineDebug(
        'zoom-scroll-apply requestedOffset=$pendingOffset '
        'clampedOffset=$clampedOffset '
        'min=${_horizontalTimelineController.position.minScrollExtent} '
        'max=${_horizontalTimelineController.position.maxScrollExtent}',
      );

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

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = math.max(
                          0.0,
                          constraints.maxWidth - trackHeaderWidth,
                        );
                        final scale = TimelineScale(
                          editorState.pixelsPerSecond,
                        );
                        final contentWidth = scale.timelineContentWidth(
                          durationSeconds: editorState.projectDurationSeconds,
                          viewportWidth: viewportWidth,
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
                                child: MouseRegion(
                                  opaque: false,
                                  onEnter: _handleTimelinePointerEnter,
                                  onExit: _handleTimelinePointerExit,
                                  child: Listener(
                                    key: _timelineViewportKey,
                                    behavior: HitTestBehavior.translucent,
                                    onPointerSignal:
                                        _handleTimelinePointerSignal,
                                    onPointerPanZoomStart:
                                        _handleTimelinePanZoomStart,
                                    onPointerPanZoomUpdate:
                                        _handleTimelinePanZoomUpdate,
                                    onPointerPanZoomEnd:
                                        _handleTimelinePanZoomEnd,
                                    child: Scrollbar(
                                      controller: _horizontalTimelineController,
                                      thumbVisibility: true,
                                      notificationPredicate: (notification) {
                                        return notification.metrics.axis ==
                                            Axis.horizontal;
                                      },
                                      child: SingleChildScrollView(
                                        controller:
                                            _horizontalTimelineController,
                                        scrollDirection: Axis.horizontal,
                                        physics:
                                            const _ControlReservedScrollPhysics(),
                                        child: SizedBox(
                                          width: contentWidth,
                                          height: constraints.maxHeight,
                                          child: Column(
                                            children: [
                                              TimelineRuler(
                                                playheadSeconds:
                                                    editorState.playheadSeconds,
                                                scale: scale,
                                                onSeek: _handleTimelineSeek,
                                              ),
                                              Expanded(
                                                child: TimelineTrackList(
                                                  scrollController:
                                                      _trackLaneScrollController,
                                                  scale: scale,
                                                  scrollPhysics:
                                                      const _ControlReservedScrollPhysics(),
                                                  onSeek: _handleTimelineSeek,
                                                ),
                                              ),
                                            ],
                                          ),
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
