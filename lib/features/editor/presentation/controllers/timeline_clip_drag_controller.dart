import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/audio_clip.dart';
import '../../domain/clip_crossfade.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_snapper.dart';
import '../widgets/track_header.dart';

enum TimelineClipDragMode { move, trimStart, trimEnd }

class TimelineClipDragState {
  const TimelineClipDragState({
    required this.clipId,
    required this.mode,
    required this.dragStartSeconds,
    required this.previewStartSeconds,
    required this.previewSourceStartSeconds,
    required this.clipDurationSeconds,
    this.trackDelta = 0,
    this.destinationTrackIndex,
    this.crossfadeSnapshots = const [],
  });

  final String clipId;
  final TimelineClipDragMode mode;
  final double dragStartSeconds;
  final double previewStartSeconds;
  final double previewSourceStartSeconds;
  final double clipDurationSeconds;
  final int trackDelta;
  final int? destinationTrackIndex;
  final List<CrossfadeDragSnapshot> crossfadeSnapshots;

  double get previewEndSeconds {
    return previewStartSeconds + clipDurationSeconds;
  }

  double get moveDeltaSeconds => previewStartSeconds - dragStartSeconds;

  List<CrossfadeDragUpdate> get crossfadeUpdates => [
    for (final snapshot in crossfadeSnapshots)
      calculateCrossfadeDragUpdate(
        snapshot: snapshot,
        timelineDeltaSeconds: moveDeltaSeconds,
        trackDelta: trackDelta,
      ),
  ];
}

class TimelineClipDragResult {
  const TimelineClipDragResult({
    required this.startSeconds,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.mode,
    required this.didMove,
    this.trackDelta = 0,
    this.crossfadeSnapshots = const [],
  });

  final double startSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final TimelineClipDragMode mode;
  final bool didMove;
  final int trackDelta;
  final List<CrossfadeDragSnapshot> crossfadeSnapshots;

  bool get didChange => didMove;
}

/// Owns a lightweight clip-drag preview and timeline edge auto-scroll.
///
/// Authoritative editor state is intentionally updated only when [end] returns
/// a committed result.
class TimelineClipDragController extends ValueNotifier<TimelineClipDragState?> {
  TimelineClipDragController(
    this._horizontalScrollController,
    this._timelineViewportKey,
    this._onTimelineInteraction, {
    this.verticalScrollController,
    this.trackViewportKey,
  }) : super(null);

  static const double _edgeThreshold = 64;
  static const double _maximumAutoScrollPixelsPerSecond = 720;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);

  final ScrollController _horizontalScrollController;
  final GlobalKey _timelineViewportKey;
  final VoidCallback _onTimelineInteraction;
  final ScrollController? verticalScrollController;
  final GlobalKey? trackViewportKey;

  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollTick;
  int? _pointer;
  double _pointerGlobalX = 0;
  double? _pointerGlobalY;
  double _dragStartPointerGlobalX = 0;
  double _dragStartScrollOffset = 0;
  double _dragStartClipSeconds = 0;
  double _dragStartSourceSeconds = 0;
  double _dragStartClipDurationSeconds = 0;
  double _minimumMoveAnchorStartSeconds = 0;
  double _sourceAudioDurationSeconds = 0;
  double _pixelsPerSecond = 1;
  double _bpm = 120;
  SnapSettings _snapSettings = const SnapSettings(enabled: false);
  int? _anchorTrackIndex;
  int? _minimumSelectedTrackIndex;
  int? _maximumSelectedTrackIndex;
  int? _trackCount;

  bool get isDragging => value != null;

  bool begin({
    required int pointer,
    required String clipId,
    required double pointerGlobalX,
    required double clipStartSeconds,
    required double clipDurationSeconds,
    required double pixelsPerSecond,
    double sourceStartSeconds = 0,
    double? sourceAudioDurationSeconds,
    double bpm = 120,
    SnapSettings snapSettings = const SnapSettings(enabled: false),
    double minimumMoveAnchorStartSeconds = 0,
    double? pointerGlobalY,
    int? anchorTrackIndex,
    int? minimumSelectedTrackIndex,
    int? maximumSelectedTrackIndex,
    int? trackCount,
    List<CrossfadeDragSnapshot> crossfadeSnapshots = const [],
  }) {
    return _begin(
      pointer: pointer,
      clipId: clipId,
      mode: TimelineClipDragMode.move,
      pointerGlobalX: pointerGlobalX,
      clipStartSeconds: clipStartSeconds,
      sourceStartSeconds: sourceStartSeconds,
      clipDurationSeconds: clipDurationSeconds,
      sourceAudioDurationSeconds:
          sourceAudioDurationSeconds ?? clipDurationSeconds,
      pixelsPerSecond: pixelsPerSecond,
      bpm: bpm,
      snapSettings: snapSettings,
      minimumMoveAnchorStartSeconds: minimumMoveAnchorStartSeconds,
      pointerGlobalY: pointerGlobalY,
      anchorTrackIndex: anchorTrackIndex,
      minimumSelectedTrackIndex: minimumSelectedTrackIndex,
      maximumSelectedTrackIndex: maximumSelectedTrackIndex,
      trackCount: trackCount,
      crossfadeSnapshots: crossfadeSnapshots,
    );
  }

  bool beginTrim({
    required int pointer,
    required String clipId,
    required TimelineClipDragMode mode,
    required double pointerGlobalX,
    required double clipStartSeconds,
    required double sourceStartSeconds,
    required double clipDurationSeconds,
    required double sourceAudioDurationSeconds,
    required double pixelsPerSecond,
    double bpm = 120,
    SnapSettings snapSettings = const SnapSettings(enabled: false),
  }) {
    assert(mode != TimelineClipDragMode.move);
    return _begin(
      pointer: pointer,
      clipId: clipId,
      mode: mode,
      pointerGlobalX: pointerGlobalX,
      clipStartSeconds: clipStartSeconds,
      sourceStartSeconds: sourceStartSeconds,
      clipDurationSeconds: clipDurationSeconds,
      sourceAudioDurationSeconds: sourceAudioDurationSeconds,
      pixelsPerSecond: pixelsPerSecond,
      bpm: bpm,
      snapSettings: snapSettings,
      minimumMoveAnchorStartSeconds: 0,
      pointerGlobalY: null,
      anchorTrackIndex: null,
      minimumSelectedTrackIndex: null,
      maximumSelectedTrackIndex: null,
      trackCount: null,
      crossfadeSnapshots: const [],
    );
  }

  bool _begin({
    required int pointer,
    required String clipId,
    required TimelineClipDragMode mode,
    required double pointerGlobalX,
    required double clipStartSeconds,
    required double sourceStartSeconds,
    required double clipDurationSeconds,
    required double sourceAudioDurationSeconds,
    required double pixelsPerSecond,
    required double bpm,
    required SnapSettings snapSettings,
    required double minimumMoveAnchorStartSeconds,
    required double? pointerGlobalY,
    required int? anchorTrackIndex,
    required int? minimumSelectedTrackIndex,
    required int? maximumSelectedTrackIndex,
    required int? trackCount,
    required List<CrossfadeDragSnapshot> crossfadeSnapshots,
  }) {
    if (isDragging ||
        !_horizontalScrollController.hasClients ||
        !pixelsPerSecond.isFinite ||
        pixelsPerSecond <= 0) {
      return false;
    }

    _pointer = pointer;
    _pointerGlobalX = pointerGlobalX;
    _pointerGlobalY = pointerGlobalY;
    _dragStartPointerGlobalX = pointerGlobalX;
    _dragStartScrollOffset = _horizontalScrollController.offset;
    _dragStartClipSeconds = math.max(0.0, clipStartSeconds);
    _dragStartSourceSeconds = math.max(0.0, sourceStartSeconds);
    _dragStartClipDurationSeconds = clipDurationSeconds;
    _minimumMoveAnchorStartSeconds = math.max(
      0.0,
      minimumMoveAnchorStartSeconds,
    );
    _sourceAudioDurationSeconds = sourceAudioDurationSeconds;
    _pixelsPerSecond = pixelsPerSecond;
    _bpm = bpm;
    _snapSettings = snapSettings;
    _anchorTrackIndex = anchorTrackIndex;
    _minimumSelectedTrackIndex = minimumSelectedTrackIndex;
    _maximumSelectedTrackIndex = maximumSelectedTrackIndex;
    _trackCount = trackCount;
    final initialTrackDelta = _calculateTrackDelta();
    value = TimelineClipDragState(
      clipId: clipId,
      mode: mode,
      dragStartSeconds: _dragStartClipSeconds,
      previewStartSeconds: _dragStartClipSeconds,
      previewSourceStartSeconds: _dragStartSourceSeconds,
      clipDurationSeconds: clipDurationSeconds,
      trackDelta: initialTrackDelta,
      destinationTrackIndex: anchorTrackIndex == null
          ? null
          : anchorTrackIndex + initialTrackDelta,
      crossfadeSnapshots: List.unmodifiable(crossfadeSnapshots),
    );
    _onTimelineInteraction();
    return true;
  }

  void update({
    required int pointer,
    required double pointerGlobalX,
    double? pointerGlobalY,
    bool bypassSnap = false,
  }) {
    if (pointer != _pointer || !isDragging) {
      return;
    }

    _pointerGlobalX = pointerGlobalX;
    _pointerGlobalY = pointerGlobalY ?? _pointerGlobalY;
    _onTimelineInteraction();
    _updatePreviewPosition(bypassSnap: bypassSnap);
    _updateAutoScroll();
  }

  TimelineClipDragResult? end(int pointer) {
    if (pointer != _pointer || value == null) {
      return null;
    }

    final finalStartSeconds = value!.previewStartSeconds;
    final result = TimelineClipDragResult(
      startSeconds: finalStartSeconds,
      sourceStartSeconds: value!.previewSourceStartSeconds,
      clipDurationSeconds: value!.clipDurationSeconds,
      mode: value!.mode,
      didMove:
          (finalStartSeconds - _dragStartClipSeconds).abs() > 0.000001 ||
          (value!.previewSourceStartSeconds - _dragStartSourceSeconds).abs() >
              0.000001 ||
          (value!.clipDurationSeconds - _dragStartClipDurationSeconds).abs() >
              0.000001 ||
          value!.trackDelta != 0,
      trackDelta: value!.trackDelta,
      crossfadeSnapshots: value!.crossfadeSnapshots,
    );

    _finish();
    return result;
  }

  void cancel(int pointer) {
    if (pointer != _pointer) {
      return;
    }

    _finish();
  }

  void _finish() {
    _stopAutoScroll();
    _pointer = null;
    _pointerGlobalY = null;
    _anchorTrackIndex = null;
    _minimumSelectedTrackIndex = null;
    _maximumSelectedTrackIndex = null;
    _trackCount = null;
    value = null;
    _onTimelineInteraction();
  }

  void _updatePreviewPosition({bool bypassSnap = false}) {
    final currentState = value;
    if (currentState == null || !_horizontalScrollController.hasClients) {
      return;
    }

    final pointerDelta = _pointerGlobalX - _dragStartPointerGlobalX;
    final scrollDelta =
        _horizontalScrollController.offset - _dragStartScrollOffset;
    final deltaSeconds = (pointerDelta + scrollDelta) / _pixelsPerSecond;
    var previewStart = _dragStartClipSeconds;
    var previewSourceStart = _dragStartSourceSeconds;
    var previewDuration = _dragStartClipDurationSeconds;
    final trackDelta = currentState.mode == TimelineClipDragMode.move
        ? _calculateTrackDelta()
        : 0;

    switch (currentState.mode) {
      case TimelineClipDragMode.move:
        previewStart = math.max(
          _minimumMoveAnchorStartSeconds,
          _snapTimelineTime(
            _dragStartClipSeconds + deltaSeconds,
            bypassSnap: bypassSnap,
          ),
        );
        break;
      case TimelineClipDragMode.trimStart:
        final minimumDuration = math.min(
          minimumClipDurationSeconds,
          _sourceAudioDurationSeconds,
        );
        final minimumDelta = math.max(
          -_dragStartClipSeconds,
          -_dragStartSourceSeconds,
        );
        final maximumDelta = _dragStartClipDurationSeconds - minimumDuration;
        final minimumTimelineStart = _dragStartClipSeconds + minimumDelta;
        final maximumTimelineStart = _dragStartClipSeconds + maximumDelta;
        final snappedTimelineStart = _snapTimelineTime(
          _dragStartClipSeconds + deltaSeconds,
          bypassSnap: bypassSnap,
        );
        final previewTimelineStart = snappedTimelineStart
            .clamp(minimumTimelineStart, maximumTimelineStart)
            .toDouble();
        final trimDelta = previewTimelineStart - _dragStartClipSeconds;
        previewStart = _dragStartClipSeconds + trimDelta;
        previewSourceStart = _dragStartSourceSeconds + trimDelta;
        previewDuration = _dragStartClipDurationSeconds - trimDelta;
        break;
      case TimelineClipDragMode.trimEnd:
        final minimumDuration = math.min(
          minimumClipDurationSeconds,
          _sourceAudioDurationSeconds,
        );
        final maximumDuration =
            _sourceAudioDurationSeconds - _dragStartSourceSeconds;
        final candidateTimelineEnd =
            _dragStartClipSeconds +
            _dragStartClipDurationSeconds +
            deltaSeconds;
        final snappedTimelineEnd = _snapTimelineTime(
          candidateTimelineEnd,
          bypassSnap: bypassSnap,
        );
        final minimumTimelineEnd = _dragStartClipSeconds + minimumDuration;
        final maximumTimelineEnd = _dragStartClipSeconds + maximumDuration;
        final previewTimelineEnd = snappedTimelineEnd
            .clamp(minimumTimelineEnd, maximumTimelineEnd)
            .toDouble();
        previewDuration = previewTimelineEnd - _dragStartClipSeconds;
        break;
    }

    if ((previewStart - currentState.previewStartSeconds).abs() < 0.000001 &&
        (previewSourceStart - currentState.previewSourceStartSeconds).abs() <
            0.000001 &&
        (previewDuration - currentState.clipDurationSeconds).abs() < 0.000001) {
      if (trackDelta == currentState.trackDelta) {
        return;
      }
    }

    value = TimelineClipDragState(
      clipId: currentState.clipId,
      mode: currentState.mode,
      dragStartSeconds: currentState.dragStartSeconds,
      previewStartSeconds: previewStart,
      previewSourceStartSeconds: previewSourceStart,
      clipDurationSeconds: previewDuration,
      trackDelta: trackDelta,
      destinationTrackIndex: _anchorTrackIndex == null
          ? null
          : _anchorTrackIndex! + trackDelta,
      crossfadeSnapshots: currentState.crossfadeSnapshots,
    );
  }

  int _calculateTrackDelta() {
    final pointerGlobalY = _pointerGlobalY;
    final anchorIndex = _anchorTrackIndex;
    final minimumIndex = _minimumSelectedTrackIndex;
    final maximumIndex = _maximumSelectedTrackIndex;
    final trackCount = _trackCount;
    final scrollController = verticalScrollController;
    final renderObject = trackViewportKey?.currentContext?.findRenderObject();
    if (pointerGlobalY == null ||
        anchorIndex == null ||
        minimumIndex == null ||
        maximumIndex == null ||
        trackCount == null ||
        trackCount <= 0 ||
        scrollController == null ||
        !scrollController.hasClients ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return 0;
    }

    final viewportTop = renderObject.localToGlobal(Offset.zero).dy;
    final contentY = pointerGlobalY - viewportTop + scrollController.offset;
    final targetIndex = (contentY / trackHeight).floor().clamp(
      0,
      trackCount - 1,
    );
    final requestedDelta = targetIndex - anchorIndex;
    final minimumDelta = -minimumIndex;
    final maximumDelta = trackCount - 1 - maximumIndex;
    return requestedDelta.clamp(minimumDelta, maximumDelta);
  }

  double _snapTimelineTime(
    double candidateSeconds, {
    required bool bypassSnap,
  }) {
    return TimelineSnapper.snapTime(
      candidateSeconds: candidateSeconds,
      bpm: _bpm,
      settings: bypassSnap
          ? _snapSettings.copyWith(enabled: false)
          : _snapSettings,
    );
  }

  void _updateAutoScroll() {
    if (_autoScrollVelocity() == 0) {
      _stopAutoScroll();
      return;
    }

    if (_autoScrollTimer != null) {
      return;
    }

    _lastAutoScrollTick = DateTime.now();
    _autoScrollTimer = Timer.periodic(
      _autoScrollInterval,
      (_) => _performAutoScrollTick(),
    );
  }

  void _performAutoScrollTick() {
    if (!isDragging || !_horizontalScrollController.hasClients) {
      _stopAutoScroll();
      return;
    }

    final velocity = _autoScrollVelocity();
    if (velocity == 0) {
      _stopAutoScroll();
      return;
    }

    final now = DateTime.now();
    final previousTick = _lastAutoScrollTick ?? now;
    _lastAutoScrollTick = now;
    final elapsedSeconds =
        now.difference(previousTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    final position = _horizontalScrollController.position;
    final target =
        (_horizontalScrollController.offset + velocity * elapsedSeconds)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();

    if ((target - _horizontalScrollController.offset).abs() < 0.01) {
      return;
    }

    _horizontalScrollController.jumpTo(target);
    _onTimelineInteraction();
    _updatePreviewPosition(bypassSnap: HardwareKeyboard.instance.isAltPressed);
  }

  double _autoScrollVelocity() {
    final renderObject = _timelineViewportKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.width <= 0) {
      return 0;
    }

    final viewportLeft = renderObject.localToGlobal(Offset.zero).dx;
    final viewportRight = viewportLeft + renderObject.size.width;
    final leftActivation = viewportLeft + _edgeThreshold;
    final rightActivation = viewportRight - _edgeThreshold;

    if (_pointerGlobalX < leftActivation) {
      final intensity = ((leftActivation - _pointerGlobalX) / _edgeThreshold)
          .clamp(0.0, 1.0)
          .toDouble();
      return -_maximumAutoScrollPixelsPerSecond * intensity;
    }

    if (_pointerGlobalX > rightActivation) {
      final intensity = ((_pointerGlobalX - rightActivation) / _edgeThreshold)
          .clamp(0.0, 1.0)
          .toDouble();
      return _maximumAutoScrollPixelsPerSecond * intensity;
    }

    return 0;
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastAutoScrollTick = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }
}
