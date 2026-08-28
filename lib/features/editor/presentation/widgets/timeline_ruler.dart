import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/loop_region.dart';
import '../../domain/musical_timing.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../../domain/timeline_snapper.dart';
import '../../domain/timeline_marker.dart';
import '../../domain/timeline_section.dart';
import '../models/timeline_ruler_mode.dart';
import 'timeline_marker_lane.dart';

class TimelineRuler extends StatefulWidget {
  const TimelineRuler({
    super.key,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.onSeek,
    this.loopRegion,
    this.isLoopEnabled = false,
    this.snapSettings = const SnapSettings(enabled: false),
    this.onLoopRegionChanged,
    this.onLoopRegionPreviewChanged,
    this.mode = TimelineRulerMode.barsBeats,
    this.bpm = 120,
    this.timeSignature = defaultTimeSignature,
    this.markers = const [],
    this.selectedMarkerId,
    this.onAddMarker,
    this.onSelectMarker,
    this.onMarkerSeek,
    this.onMarkerMoveStart,
    this.onMarkerMovePreview,
    this.onMarkerMoveEnd,
    this.onMarkerMoveCancel,
    this.onMarkerRename,
    this.onMarkerColorSelected,
    this.onMarkerDelete,
    this.sections = const [],
    this.selectedSectionId,
    this.onAddSection,
    this.onSelectSection,
    this.onSectionEditStart,
    this.onSectionMovePreview,
    this.onSectionStartResizePreview,
    this.onSectionEndResizePreview,
    this.onSectionEditEnd,
    this.onSectionEditCancel,
    this.onSectionRename,
    this.onSectionColorSelected,
    this.onSectionDelete,
    this.onEmptySectionLaneTap,
  });

  static const double musicalLaneHeight = 32;
  static const double height = musicalLaneHeight + TimelineMarkerLane.height;

  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final ValueChanged<double> onSeek;
  final LoopRegion? loopRegion;
  final bool isLoopEnabled;
  final SnapSettings snapSettings;
  final ValueChanged<LoopRegion>? onLoopRegionChanged;
  final ValueChanged<LoopRegion?>? onLoopRegionPreviewChanged;
  final TimelineRulerMode mode;
  final double bpm;
  final TimeSignature timeSignature;
  final List<TimelineMarker> markers;
  final String? selectedMarkerId;
  final ValueChanged<double>? onAddMarker;
  final ValueChanged<String>? onSelectMarker;
  final ValueChanged<double>? onMarkerSeek;
  final ValueChanged<String>? onMarkerMoveStart;
  final void Function(String markerId, double timeSeconds)? onMarkerMovePreview;
  final ValueChanged<String>? onMarkerMoveEnd;
  final ValueChanged<String>? onMarkerMoveCancel;
  final void Function(String markerId, String name)? onMarkerRename;
  final void Function(String markerId, int colorArgb)? onMarkerColorSelected;
  final ValueChanged<String>? onMarkerDelete;
  final List<TimelineSection> sections;
  final String? selectedSectionId;
  final void Function(double startTime, double endTime)? onAddSection;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<String>? onSectionEditStart;
  final void Function(String sectionId, double startTime)? onSectionMovePreview;
  final void Function(String sectionId, double startTime)?
  onSectionStartResizePreview;
  final void Function(String sectionId, double endTime)?
  onSectionEndResizePreview;
  final void Function(String sectionId, bool isResize)? onSectionEditEnd;
  final ValueChanged<String>? onSectionEditCancel;
  final void Function(String sectionId, String name)? onSectionRename;
  final void Function(String sectionId, int colorArgb)? onSectionColorSelected;
  final ValueChanged<String>? onSectionDelete;
  final VoidCallback? onEmptySectionLaneTap;

  @override
  State<TimelineRuler> createState() => _TimelineRulerState();
}

enum _LoopDragMode { create, start, end }

class _TimelineRulerState extends State<TimelineRuler> {
  static const double _dragThresholdPixels = 4;
  static const double _handleHitWidth = 9;

  int? _pointer;
  double _pointerDownX = 0;
  bool _isDragging = false;
  _LoopDragMode _dragMode = _LoopDragMode.create;
  LoopRegion? _dragBaseRegion;
  LoopRegion? _previewRegion;
  MouseCursor _cursor = MouseCursor.defer;

  double _timeAt(double x) {
    return widget.gridMetrics.transform.contentXToTime(x);
  }

  double _snap(double seconds) {
    return TimelineSnapper.snapTime(
      candidateSeconds: seconds,
      bpm: widget.bpm,
      settings: widget.snapSettings,
      timeSignature: widget.timeSignature,
    );
  }

  double get _minimumDuration {
    if (!widget.snapSettings.enabled) {
      return minimumLoopDurationSeconds;
    }
    return TimelineSnapper.intervalSeconds(
      bpm: widget.bpm,
      subdivision: widget.snapSettings.subdivision,
      timeSignature: widget.timeSignature,
    );
  }

  _LoopDragMode _modeAt(double x) {
    final region = widget.loopRegion;
    if (region == null) {
      return _LoopDragMode.create;
    }
    final startX = widget.gridMetrics.transform.timeToContentX(
      region.startSeconds,
    );
    final endX = widget.gridMetrics.transform.timeToContentX(region.endSeconds);
    if ((x - startX).abs() <= _handleHitWidth) {
      return _LoopDragMode.start;
    }
    if ((x - endX).abs() <= _handleHitWidth) {
      return _LoopDragMode.end;
    }
    return _LoopDragMode.create;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if ((event.buttons & kPrimaryMouseButton) == 0 || _pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _pointerDownX = event.localPosition.dx;
    _dragMode = _modeAt(_pointerDownX);
    _dragBaseRegion = widget.loopRegion;
    _isDragging = false;
    _previewRegion = null;
    widget.onLoopRegionPreviewChanged?.call(null);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      _finishPointer(event.pointer, event.localPosition.dx);
      return;
    }
    if (!_isDragging &&
        (event.localPosition.dx - _pointerDownX).abs() < _dragThresholdPixels) {
      return;
    }

    _isDragging = true;
    final candidate = _snap(_timeAt(event.localPosition.dx));
    final region = _dragBaseRegion;
    final first = switch (_dragMode) {
      _LoopDragMode.create => _snap(_timeAt(_pointerDownX)),
      _LoopDragMode.start => region?.endSeconds ?? candidate,
      _LoopDragMode.end => region?.startSeconds ?? candidate,
    };
    final preview = LoopRegion.normalized(
      firstSeconds: first,
      secondSeconds: candidate,
      minimumDurationSeconds: _minimumDuration,
    );
    setState(() => _previewRegion = preview);
    widget.onLoopRegionPreviewChanged?.call(preview);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _finishPointer(event.pointer, event.localPosition.dx);
  }

  void _finishPointer(int pointer, double x) {
    if (pointer != _pointer) {
      return;
    }
    final wasDragging = _isDragging;
    final preview = _previewRegion;
    _pointer = null;
    _isDragging = false;
    _previewRegion = null;
    _dragBaseRegion = null;

    if (wasDragging && preview != null) {
      widget.onLoopRegionChanged?.call(preview);
      widget.onLoopRegionPreviewChanged?.call(null);
    } else {
      widget.onLoopRegionPreviewChanged?.call(null);
      widget.onSeek(_timeAt(x));
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    setState(() {
      _pointer = null;
      _isDragging = false;
      _dragBaseRegion = null;
      _previewRegion = null;
    });
    widget.onLoopRegionPreviewChanged?.call(null);
  }

  void _handleHover(PointerHoverEvent event) {
    final next = _modeAt(event.localPosition.dx) == _LoopDragMode.create
        ? MouseCursor.defer
        : SystemMouseCursors.resizeLeftRight;
    if (next != _cursor) {
      setState(() => _cursor = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: TimelineRuler.height,
      child: Column(
        children: [
          MouseRegion(
            cursor: _isDragging ? SystemMouseCursors.resizeLeftRight : _cursor,
            onHover: _handleHover,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: SizedBox(
                height: TimelineRuler.musicalLaneHeight,
                child: CustomPaint(
                  painter: TimelineRulerPainter(
                    color: colorScheme.outline,
                    playheadColor: colorScheme.tertiary,
                    loopColor: colorScheme.primary,
                    loopRegion: _previewRegion ?? widget.loopRegion,
                    isLoopEnabled: widget.isLoopEnabled,
                    playheadSeconds: widget.playheadSeconds,
                    gridMetrics: widget.gridMetrics,
                    mode: widget.mode,
                    bpm: widget.bpm,
                    timeSignature: widget.timeSignature,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          TimelineMarkerLane(
            markers: widget.markers,
            selectedMarkerId: widget.selectedMarkerId,
            playheadSeconds: widget.playheadSeconds,
            gridMetrics: widget.gridMetrics,
            onAddMarker: widget.onAddMarker,
            onSelectMarker: widget.onSelectMarker,
            onSeek: widget.onMarkerSeek ?? widget.onSeek,
            onMoveStart: widget.onMarkerMoveStart,
            onMovePreview: widget.onMarkerMovePreview,
            onMoveEnd: widget.onMarkerMoveEnd,
            onMoveCancel: widget.onMarkerMoveCancel,
            onRename: widget.onMarkerRename,
            onColorSelected: widget.onMarkerColorSelected,
            onDelete: widget.onMarkerDelete,
            sections: widget.sections,
            selectedSectionId: widget.selectedSectionId,
            bpm: widget.bpm,
            timeSignature: widget.timeSignature,
            snapSettings: widget.snapSettings,
            onAddSection: widget.onAddSection,
            onSelectSection: widget.onSelectSection,
            onSectionEditStart: widget.onSectionEditStart,
            onSectionMovePreview: widget.onSectionMovePreview,
            onSectionStartResizePreview: widget.onSectionStartResizePreview,
            onSectionEndResizePreview: widget.onSectionEndResizePreview,
            onSectionEditEnd: widget.onSectionEditEnd,
            onSectionEditCancel: widget.onSectionEditCancel,
            onSectionRename: widget.onSectionRename,
            onSectionColorSelected: widget.onSectionColorSelected,
            onSectionDelete: widget.onSectionDelete,
            onEmptyTap: widget.onEmptySectionLaneTap,
          ),
        ],
      ),
    );
  }
}

class TimelineRulerPainter extends CustomPainter {
  const TimelineRulerPainter({
    required this.color,
    required this.playheadColor,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.mode,
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
    required this.devicePixelRatio,
    this.loopColor = Colors.blue,
    this.loopRegion,
    this.isLoopEnabled = false,
  });

  static const double _minimumTickSpacing = 8;
  static const double _minimumLabelSpacing = 42;
  static const double _labelGap = 6;

  final Color color;
  final Color playheadColor;
  final Color loopColor;
  final LoopRegion? loopRegion;
  final bool isLoopEnabled;
  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final TimelineRulerMode mode;
  final double bpm;
  final TimeSignature timeSignature;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLoopRegion(canvas, size);
    switch (mode) {
      case TimelineRulerMode.barsBeats:
        _paintMusicalTicks(canvas, size);
        break;
      case TimelineRulerMode.time:
        _paintTimeTicks(canvas, size);
        break;
    }

    _paintPlayhead(canvas, size);
  }

  void _paintLoopRegion(Canvas canvas, Size size) {
    final region = loopRegion;
    if (region == null) {
      return;
    }
    final startX = gridMetrics.transform.timeToContentX(region.startSeconds);
    final endX = gridMetrics.transform.timeToContentX(region.endSeconds);
    final fill = Paint()
      ..color = loopColor.withValues(alpha: isLoopEnabled ? 0.24 : 0.13);
    final boundary = Paint()
      ..color = loopColor.withValues(alpha: isLoopEnabled ? 0.95 : 0.65)
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), fill);
    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), boundary);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), boundary);
    canvas.drawRect(Rect.fromLTWH(startX - 3, 0, 6, 7), boundary);
    canvas.drawRect(Rect.fromLTWH(endX - 3, 0, 6, 7), boundary);
  }

  void _paintTimeTicks(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final clipBounds = canvas.getLocalClipBounds();
    var previousLabelRight = double.negativeInfinity;

    for (final tick in gridMetrics.ticksInContentRange(
      left: clipBounds.left,
      right: clipBounds.right,
      contentWidth: size.width,
    )) {
      final x = _alignedX(tick.contentX);

      canvas.drawLine(
        Offset(x, tick.isMajor ? 18 : 25),
        Offset(x, size.height),
        tick.isMajor ? majorPaint : minorPaint,
      );

      if (!tick.isMajor) {
        continue;
      }

      previousLabelRight = _paintLabelIfClear(
        canvas: canvas,
        textPainter: textPainter,
        label: gridMetrics.scale.formatTickLabel(tick.timeSeconds),
        x: x,
        previousLabelRight: previousLabelRight,
      );
    }
  }

  void _paintMusicalTicks(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final timing = MusicalTiming(bpm: bpm, timeSignature: timeSignature);
    final transform = gridMetrics.transform;
    final clipBounds = canvas.getLocalClipBounds();
    final visibleStartSeconds = math.max(
      0.0,
      transform.contentXToTime(clipBounds.left),
    );
    final visibleEndSeconds = math.min(
      transform.contentXToTime(size.width),
      transform.contentXToTime(clipBounds.right),
    );

    if (visibleEndSeconds < visibleStartSeconds) {
      return;
    }

    final beatSeconds = timing.beatDurationSeconds;
    final beatSpacing = transform.timeToContentX(beatSeconds);
    final barSpacing = transform.timeToContentX(timing.barDurationSeconds);
    final subdivisionCount = _visibleSubdivisionsPerBeat(beatSpacing);

    if (subdivisionCount > 1) {
      _paintSubdivisions(
        canvas: canvas,
        size: size,
        visibleStartSeconds: visibleStartSeconds,
        visibleEndSeconds: visibleEndSeconds,
        beatSeconds: beatSeconds,
        subdivisionsPerBeat: subdivisionCount,
      );
    }

    if (beatSpacing >= _minimumTickSpacing) {
      _paintBeatTicks(
        canvas: canvas,
        size: size,
        timing: timing,
        visibleStartSeconds: visibleStartSeconds,
        visibleEndSeconds: visibleEndSeconds,
      );
    }

    _paintBarTicks(
      canvas: canvas,
      size: size,
      timing: timing,
      visibleStartSeconds: visibleStartSeconds,
      visibleEndSeconds: visibleEndSeconds,
      barSpacing: barSpacing,
    );

    _paintMusicalLabels(
      canvas: canvas,
      timing: timing,
      visibleStartSeconds: visibleStartSeconds,
      visibleEndSeconds: visibleEndSeconds,
      beatSpacing: beatSpacing,
      barSpacing: barSpacing,
    );
  }

  int _visibleSubdivisionsPerBeat(double beatSpacing) {
    for (final divisions in const [8, 4, 2]) {
      if (beatSpacing / divisions >= _minimumTickSpacing) {
        return divisions;
      }
    }
    return 1;
  }

  void _paintSubdivisions({
    required Canvas canvas,
    required Size size,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double beatSeconds,
    required int subdivisionsPerBeat,
  }) {
    final intervalSeconds = beatSeconds / subdivisionsPerBeat;
    final firstIndex = math.max(
      0,
      (visibleStartSeconds / intervalSeconds).floor() - 1,
    );
    final lastIndex = (visibleEndSeconds / intervalSeconds).ceil() + 1;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (var index = firstIndex; index <= lastIndex; index++) {
      if (index % subdivisionsPerBeat == 0) {
        continue;
      }
      final timeSeconds = index * intervalSeconds;
      final x = _alignedX(gridMetrics.transform.timeToContentX(timeSeconds));
      canvas.drawLine(Offset(x, 27), Offset(x, size.height), paint);
    }
  }

  void _paintBeatTicks({
    required Canvas canvas,
    required Size size,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
  }) {
    final beatSeconds = timing.beatDurationSeconds;
    final firstBeatIndex = math.max(
      0,
      (visibleStartSeconds / beatSeconds).floor() - 1,
    );
    final lastBeatIndex = (visibleEndSeconds / beatSeconds).ceil() + 1;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.58)
      ..strokeWidth = 1;

    for (
      var beatIndex = firstBeatIndex;
      beatIndex <= lastBeatIndex;
      beatIndex++
    ) {
      if (timing.isDownbeat(beatIndex)) {
        continue;
      }
      final x = _alignedX(
        gridMetrics.transform.timeToContentX(timing.beatTimeSeconds(beatIndex)),
      );
      canvas.drawLine(Offset(x, 21), Offset(x, size.height), paint);
    }
  }

  void _paintBarTicks({
    required Canvas canvas,
    required Size size,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double barSpacing,
  }) {
    final barSeconds = timing.barDurationSeconds;
    final stride = math.max(1, (_minimumTickSpacing / barSpacing).ceil());
    final firstVisibleBar = math.max(
      0,
      (visibleStartSeconds / barSeconds).floor() - 1,
    );
    final firstBar = firstVisibleBar - firstVisibleBar % stride;
    final lastBar = (visibleEndSeconds / barSeconds).ceil() + stride;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var barIndex = firstBar; barIndex <= lastBar; barIndex += stride) {
      final timeSeconds = barIndex * barSeconds;
      final x = _alignedX(gridMetrics.transform.timeToContentX(timeSeconds));
      canvas.drawLine(Offset(x, 15), Offset(x, size.height), paint);
    }
  }

  void _paintMusicalLabels({
    required Canvas canvas,
    required MusicalTiming timing,
    required double visibleStartSeconds,
    required double visibleEndSeconds,
    required double beatSpacing,
    required double barSpacing,
  }) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    var previousLabelRight = double.negativeInfinity;

    if (beatSpacing >= _minimumLabelSpacing) {
      final beatSeconds = timing.beatDurationSeconds;
      final firstBeatIndex = math.max(
        0,
        (visibleStartSeconds / beatSeconds).floor() - 1,
      );
      final lastBeatIndex = (visibleEndSeconds / beatSeconds).ceil() + 1;

      for (
        var beatIndex = firstBeatIndex;
        beatIndex <= lastBeatIndex;
        beatIndex++
      ) {
        final x = _alignedX(
          gridMetrics.transform.timeToContentX(
            timing.beatTimeSeconds(beatIndex),
          ),
        );
        previousLabelRight = _paintLabelIfClear(
          canvas: canvas,
          textPainter: textPainter,
          label: timing.positionAtBeatIndex(beatIndex).label,
          x: x,
          previousLabelRight: previousLabelRight,
        );
      }
      return;
    }

    final barSeconds = timing.barDurationSeconds;
    final labelStride = math.max(1, (_minimumLabelSpacing / barSpacing).ceil());
    final firstVisibleBar = math.max(
      0,
      (visibleStartSeconds / barSeconds).floor() - 1,
    );
    final firstBar = firstVisibleBar - firstVisibleBar % labelStride;
    final lastBar = (visibleEndSeconds / barSeconds).ceil() + labelStride;

    for (
      var barIndex = firstBar;
      barIndex <= lastBar;
      barIndex += labelStride
    ) {
      final x = _alignedX(
        gridMetrics.transform.timeToContentX(barIndex * barSeconds),
      );
      previousLabelRight = _paintLabelIfClear(
        canvas: canvas,
        textPainter: textPainter,
        label: '${barIndex + 1}',
        x: x,
        previousLabelRight: previousLabelRight,
      );
    }
  }

  double _paintLabelIfClear({
    required Canvas canvas,
    required TextPainter textPainter,
    required String label,
    required double x,
    required double previousLabelRight,
  }) {
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(color: color, fontSize: 10),
    );
    textPainter.layout();

    final labelX = x + 4;
    if (labelX < previousLabelRight + _labelGap) {
      return previousLabelRight;
    }

    textPainter.paint(canvas, Offset(labelX, 2));
    return labelX + textPainter.width;
  }

  void _paintPlayhead(Canvas canvas, Size size) {
    final playheadX = gridMetrics.alignStrokeCenter(
      gridMetrics.transform.timeToContentX(playheadSeconds),
      devicePixelRatio: devicePixelRatio,
      strokeWidth: 2,
    );
    final playheadPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    final marker = Path()
      ..moveTo(playheadX - 5, 0)
      ..lineTo(playheadX + 5, 0)
      ..lineTo(playheadX, 7)
      ..close();

    canvas.drawPath(marker, playheadPaint);
  }

  double _alignedX(double contentX) {
    return gridMetrics.alignStrokeCenter(
      contentX,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  bool shouldRepaint(covariant TimelineRulerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.playheadSeconds != playheadSeconds ||
        oldDelegate.loopColor != loopColor ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.isLoopEnabled != isLoopEnabled ||
        oldDelegate.gridMetrics.scale.pixelsPerSecond !=
            gridMetrics.scale.pixelsPerSecond ||
        oldDelegate.gridMetrics.transform.horizontalScrollOffset !=
            gridMetrics.transform.horizontalScrollOffset ||
        oldDelegate.mode != mode ||
        oldDelegate.bpm != bpm ||
        oldDelegate.timeSignature != timeSignature ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
