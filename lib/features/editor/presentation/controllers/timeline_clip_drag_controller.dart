import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimelineClipDragState {
  const TimelineClipDragState({
    required this.clipId,
    required this.previewStartSeconds,
    required this.clipDurationSeconds,
  });

  final String clipId;
  final double previewStartSeconds;
  final double clipDurationSeconds;

  double get previewEndSeconds {
    return previewStartSeconds + clipDurationSeconds;
  }
}

class TimelineClipDragResult {
  const TimelineClipDragResult({
    required this.startSeconds,
    required this.didMove,
  });

  final double startSeconds;
  final bool didMove;
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
  double _pixelsPerSecond = 1;

  bool get isDragging => value != null;

  bool begin({
    required int pointer,
    required String clipId,
    required double pointerGlobalX,
    required double clipStartSeconds,
    required double clipDurationSeconds,
    required double pixelsPerSecond,
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
    _pixelsPerSecond = pixelsPerSecond;
    value = TimelineClipDragState(
      clipId: clipId,
      previewStartSeconds: _dragStartClipSeconds,
      clipDurationSeconds: clipDurationSeconds,
    );
    _onTimelineInteraction();
    return true;
  }

  void update({required int pointer, required double pointerGlobalX}) {
    if (pointer != _pointer || !isDragging) {
      return;
    }

    _pointerGlobalX = pointerGlobalX;
    _onTimelineInteraction();
    _updatePreviewPosition();
    _updateAutoScroll();
  }

  TimelineClipDragResult? end(int pointer) {
    if (pointer != _pointer || value == null) {
      return null;
    }

    final finalStartSeconds = value!.previewStartSeconds;
    final result = TimelineClipDragResult(
      startSeconds: finalStartSeconds,
      didMove: (finalStartSeconds - _dragStartClipSeconds).abs() > 0.000001,
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

  void _updatePreviewPosition() {
    final currentState = value;
    if (currentState == null || !_horizontalScrollController.hasClients) {
      return;
    }

    final pointerDelta = _pointerGlobalX - _dragStartPointerGlobalX;
    final scrollDelta =
        _horizontalScrollController.offset - _dragStartScrollOffset;
    final previewStart = math.max(
      0.0,
      _dragStartClipSeconds + (pointerDelta + scrollDelta) / _pixelsPerSecond,
    );

    if ((previewStart - currentState.previewStartSeconds).abs() < 0.000001) {
      return;
    }

    value = TimelineClipDragState(
      clipId: currentState.clipId,
      previewStartSeconds: previewStart,
      clipDurationSeconds: currentState.clipDurationSeconds,
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
    _updatePreviewPosition();
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
