import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/audio_clip.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_snapper.dart';

enum TimelineClipDragMode { move, trimStart, trimEnd }

class TimelineClipDragState {
  const TimelineClipDragState({
    required this.clipId,
    required this.mode,
    required this.previewStartSeconds,
    required this.previewSourceStartSeconds,
    required this.clipDurationSeconds,
  });

  final String clipId;
  final TimelineClipDragMode mode;
  final double previewStartSeconds;
  final double previewSourceStartSeconds;
  final double clipDurationSeconds;

  double get previewEndSeconds {
    return previewStartSeconds + clipDurationSeconds;
  }
}

class TimelineClipDragResult {
  const TimelineClipDragResult({
    required this.startSeconds,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.mode,
    required this.didMove,
  });

  final double startSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final TimelineClipDragMode mode;
  final bool didMove;

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
    this._onTimelineInteraction,
  ) : super(null);

  static const double _edgeThreshold = 64;
  static const double _maximumAutoScrollPixelsPerSecond = 720;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);

  final ScrollController _horizontalScrollController;
  final GlobalKey _timelineViewportKey;
  final VoidCallback _onTimelineInteraction;

  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollTick;
  int? _pointer;
  double _pointerGlobalX = 0;
  double _dragStartPointerGlobalX = 0;
  double _dragStartScrollOffset = 0;
  double _dragStartClipSeconds = 0;
  double _dragStartSourceSeconds = 0;
  double _dragStartClipDurationSeconds = 0;
  double _sourceAudioDurationSeconds = 0;
  double _pixelsPerSecond = 1;
  double _bpm = 120;
  SnapSettings _snapSettings = const SnapSettings(enabled: false);

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
  }) {
    if (isDragging ||
        !_horizontalScrollController.hasClients ||
        !pixelsPerSecond.isFinite ||
        pixelsPerSecond <= 0) {
      return false;
    }

    _pointer = pointer;
    _pointerGlobalX = pointerGlobalX;
    _dragStartPointerGlobalX = pointerGlobalX;
    _dragStartScrollOffset = _horizontalScrollController.offset;
    _dragStartClipSeconds = math.max(0.0, clipStartSeconds);
    _dragStartSourceSeconds = math.max(0.0, sourceStartSeconds);
    _dragStartClipDurationSeconds = clipDurationSeconds;
    _sourceAudioDurationSeconds = sourceAudioDurationSeconds;
    _pixelsPerSecond = pixelsPerSecond;
    _bpm = bpm;
    _snapSettings = snapSettings;
    value = TimelineClipDragState(
      clipId: clipId,
      mode: mode,
      previewStartSeconds: _dragStartClipSeconds,
      previewSourceStartSeconds: _dragStartSourceSeconds,
      clipDurationSeconds: clipDurationSeconds,
    );
    _onTimelineInteraction();
    return true;
  }

  void update({
    required int pointer,
    required double pointerGlobalX,
    bool bypassSnap = false,
  }) {
    if (pointer != _pointer || !isDragging) {
      return;
    }

    _pointerGlobalX = pointerGlobalX;
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
              0.000001,
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

    switch (currentState.mode) {
      case TimelineClipDragMode.move:
        previewStart = _snapTimelineTime(
          _dragStartClipSeconds + deltaSeconds,
          bypassSnap: bypassSnap,
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
      return;
    }

    value = TimelineClipDragState(
      clipId: currentState.clipId,
      mode: currentState.mode,
      previewStartSeconds: previewStart,
      previewSourceStartSeconds: previewSourceStart,
      clipDurationSeconds: previewDuration,
    );
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
