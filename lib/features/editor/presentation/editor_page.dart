import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../application/editor_controller.dart';
import '../domain/timeline_scale.dart';
import '../infrastructure/audio_import_service.dart';
import 'models/app_command.dart';
import 'widgets/commands_dialog.dart';
import 'widgets/editor_menu_bar.dart';
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

  bool _isDragging = false;
  bool _isSyncingVerticalScroll = false;
  bool _isProgrammaticTimelineScroll = false;
  double? _pendingHorizontalOffset;
  double? _lastPanZoomScale;
  DateTime? _lastTimelineInteraction;

  final GlobalKey _timelineViewportKey = GlobalKey();

  late final ScrollController _horizontalTimelineController;
  late final ScrollController _trackHeaderScrollController;
  late final ScrollController _trackLaneScrollController;
  late final List<EditorMenuSection> _menuSections;

  @override
  void initState() {
    super.initState();

    _horizontalTimelineController = ScrollController();
    _trackHeaderScrollController = ScrollController();
    _trackLaneScrollController = ScrollController();
    _menuSections = [
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
    ref.read(editorControllerProvider.notifier).seek(positionSeconds);
  }

  void _openCommandsDialog() {
    showCommandsDialog(context, commands: EditorCommands.all);
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
      if (!ctrlPressed) {
        if (event.scrollDelta.dx != 0 ||
            (HardwareKeyboard.instance.isShiftPressed &&
                event.scrollDelta.dy != 0)) {
          _markTimelineUserInteraction();
        }
        return;
      }

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
    final requestedOffset = oldScale.scrollOffsetKeepingAnchor(
      newScale: newScale,
      currentScrollOffset: currentOffset,
      viewportX: focalX,
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
                  EditorMenuBar(sections: _menuSections),

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
                                child: Listener(
                                  key: _timelineViewportKey,
                                  behavior: HitTestBehavior.translucent,
                                  onPointerSignal: _handleTimelinePointerSignal,
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
                                      controller: _horizontalTimelineController,
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
