import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/musical_timing.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_marker.dart';
import '../../domain/timeline_scale.dart';
import '../../domain/timeline_section.dart';
import '../../domain/timeline_snapper.dart';
import 'marker_properties_popover.dart';
import 'daw_interaction_hint.dart';
import 'section_properties_popover.dart';

class TimelineMarkerLane extends StatefulWidget {
  const TimelineMarkerLane({
    super.key,
    required this.markers,
    required this.selectedMarkerId,
    required this.playheadSeconds,
    required this.gridMetrics,
    required this.onAddMarker,
    required this.onSelectMarker,
    required this.onSeek,
    required this.onMoveStart,
    required this.onMovePreview,
    required this.onMoveEnd,
    required this.onMoveCancel,
    required this.onRename,
    required this.onColorSelected,
    required this.onDelete,
    this.sections = const [],
    this.selectedSectionId,
    this.bpm = 120,
    this.timeSignature = defaultTimeSignature,
    this.snapSettings = const SnapSettings(enabled: false),
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
    this.onEmptyTap,
  });

  static const double height = 22;

  final List<TimelineMarker> markers;
  final String? selectedMarkerId;
  final double playheadSeconds;
  final TimelineGridMetrics gridMetrics;
  final ValueChanged<double>? onAddMarker;
  final ValueChanged<String>? onSelectMarker;
  final ValueChanged<double> onSeek;
  final ValueChanged<String>? onMoveStart;
  final void Function(String markerId, double timeSeconds)? onMovePreview;
  final ValueChanged<String>? onMoveEnd;
  final ValueChanged<String>? onMoveCancel;
  final void Function(String markerId, String name)? onRename;
  final void Function(String markerId, int colorArgb)? onColorSelected;
  final ValueChanged<String>? onDelete;
  final List<TimelineSection> sections;
  final String? selectedSectionId;
  final double bpm;
  final TimeSignature timeSignature;
  final SnapSettings snapSettings;
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
  final VoidCallback? onEmptyTap;

  @override
  State<TimelineMarkerLane> createState() => _TimelineMarkerLaneState();
}

class _TimelineMarkerLaneState extends State<TimelineMarkerLane> {
  static const double _creationThresholdPixels = 4;
  bool _mayCreateSection = false;
  double _creationAnchorX = 0;
  TimelineSection? _creationPreview;

  double _timeAt(double x) =>
      widget.gridMetrics.transform.contentXToTime(x).clamp(0, double.infinity);

  double _snap(double seconds) => TimelineSnapper.snapTime(
    candidateSeconds: seconds,
    bpm: widget.bpm,
    timeSignature: widget.timeSignature,
    settings: widget.snapSettings,
  );

  bool _hitsItem(double x, Map<String, double> markerWidths) {
    for (final section in widget.sections) {
      final left = widget.gridMetrics.transform.timeToContentX(
        section.startTime,
      );
      final right = widget.gridMetrics.transform.timeToContentX(
        section.endTime,
      );
      if (x >= left && x <= right) return true;
    }
    for (final marker in widget.markers) {
      final left =
          widget.gridMetrics.transform.timeToContentX(marker.timeSeconds) - 5;
      if (x >= left && x <= left + markerWidths[marker.id]!) return true;
    }
    return false;
  }

  void _prepareCreation(DragDownDetails details, Map<String, double> widths) {
    _mayCreateSection = !_hitsItem(details.localPosition.dx, widths);
    _creationAnchorX = details.localPosition.dx;
    _creationPreview = null;
  }

  void _updateCreation(DragUpdateDetails details) {
    if (!_mayCreateSection ||
        (details.localPosition.dx - _creationAnchorX).abs() <
            _creationThresholdPixels) {
      return;
    }
    final first = _snap(_timeAt(_creationAnchorX));
    final second = _snap(_timeAt(details.localPosition.dx));
    final start = math.min(first, second);
    final end = math.max(first, second);
    if (end - start <= 0.000001) return;
    setState(() {
      _creationPreview = TimelineSection(
        id: '__section-preview__',
        startTime: start,
        endTime: end,
        name: 'New Section',
        colorArgb: 0xff78909c,
      );
    });
  }

  void _finishCreation() {
    if (!_mayCreateSection) return;
    final preview = _creationPreview;
    _mayCreateSection = false;
    _creationPreview = null;
    if (mounted) setState(() {});
    if (preview != null) {
      widget.onAddSection?.call(preview.startTime, preview.endTime);
    } else {
      widget.onEmptyTap?.call();
    }
  }

  void _cancelCreation() {
    setState(() {
      _mayCreateSection = false;
      _creationPreview = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final orderedMarkers = [
      ...widget.markers.where((m) => m.id != widget.selectedMarkerId),
      ...widget.markers.where((m) => m.id == widget.selectedMarkerId),
    ];
    final orderedSections = [
      ...widget.sections.where((s) => s.id != widget.selectedSectionId),
      ...widget.sections.where((s) => s.id == widget.selectedSectionId),
    ];
    final markerWidths = {
      for (final marker in widget.markers)
        marker.id: _markerFlagWidth(marker.name, Directionality.of(context)),
    };
    return DawInteractionHint(
      data: DawInteractionHints.sectionLane,
      child: GestureDetector(
        key: const ValueKey('timeline-marker-lane'),
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: widget.onAddMarker == null
            ? null
            : (details) {
                if (!_hitsItem(details.localPosition.dx, markerWidths)) {
                  widget.onAddMarker!(_timeAt(details.localPosition.dx));
                }
              },
        onHorizontalDragDown: (details) =>
            _prepareCreation(details, markerWidths),
        onHorizontalDragUpdate: _updateCreation,
        onHorizontalDragEnd: (_) => _finishCreation(),
        onHorizontalDragCancel: _cancelCreation,
        child: Container(
          height: TimelineMarkerLane.height,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .75),
              ),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final section in orderedSections)
                _positionedSection(section),
              if (_creationPreview case final preview?)
                _positionedSection(preview, isPreview: true),
              Positioned(
                left:
                    widget.gridMetrics.transform.timeToContentX(
                      widget.playheadSeconds,
                    ) -
                    1,
                top: 0,
                bottom: 0,
                width: 2,
                child: IgnorePointer(child: ColoredBox(color: colors.tertiary)),
              ),
              for (final marker in orderedMarkers)
                Positioned(
                  key: ValueKey('timeline-marker-${marker.id}'),
                  left:
                      widget.gridMetrics.transform.timeToContentX(
                        marker.timeSeconds,
                      ) -
                      5,
                  top: 0,
                  width: markerWidths[marker.id],
                  height: TimelineMarkerLane.height,
                  child: _TimelineMarkerFlag(
                    marker: marker,
                    isSelected: marker.id == widget.selectedMarkerId,
                    pixelsPerSecond: widget.gridMetrics.scale.pixelsPerSecond,
                    onSelect: widget.onSelectMarker == null
                        ? null
                        : () {
                            widget.onSelectMarker!(marker.id);
                            widget.onSeek(marker.timeSeconds);
                          },
                    onMoveStart: widget.onMoveStart == null
                        ? null
                        : () => widget.onMoveStart!(marker.id),
                    onMovePreview: widget.onMovePreview == null
                        ? null
                        : (time) => widget.onMovePreview!(marker.id, time),
                    onMoveEnd: widget.onMoveEnd == null
                        ? null
                        : () => widget.onMoveEnd!(marker.id),
                    onMoveCancel: widget.onMoveCancel == null
                        ? null
                        : () => widget.onMoveCancel!(marker.id),
                    onRename: widget.onRename == null
                        ? null
                        : (name) => widget.onRename!(marker.id, name),
                    onColorSelected: widget.onColorSelected == null
                        ? null
                        : (color) => widget.onColorSelected!(marker.id, color),
                    onDelete: widget.onDelete == null
                        ? null
                        : () => widget.onDelete!(marker.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedSection(TimelineSection section, {bool isPreview = false}) {
    final left = widget.gridMetrics.transform.timeToContentX(section.startTime);
    final right = widget.gridMetrics.transform.timeToContentX(section.endTime);
    return Positioned(
      key: ValueKey('timeline-section-${section.id}'),
      left: left,
      top: 1,
      width: math.max(1, right - left),
      height: TimelineMarkerLane.height - 2,
      child: IgnorePointer(
        ignoring: isPreview,
        child: _TimelineSectionStrip(
          section: section,
          isSelected: section.id == widget.selectedSectionId,
          isPreview: isPreview,
          pixelsPerSecond: widget.gridMetrics.scale.pixelsPerSecond,
          onSelect: widget.onSelectSection == null
              ? null
              : () => widget.onSelectSection!(section.id),
          onSeek: () => widget.onSeek(section.startTime),
          onEditStart: widget.onSectionEditStart == null
              ? null
              : () => widget.onSectionEditStart!(section.id),
          onMovePreview: widget.onSectionMovePreview == null
              ? null
              : (time) => widget.onSectionMovePreview!(section.id, time),
          onStartResizePreview: widget.onSectionStartResizePreview == null
              ? null
              : (time) => widget.onSectionStartResizePreview!(section.id, time),
          onEndResizePreview: widget.onSectionEndResizePreview == null
              ? null
              : (time) => widget.onSectionEndResizePreview!(section.id, time),
          onEditEnd: widget.onSectionEditEnd == null
              ? null
              : (resize) => widget.onSectionEditEnd!(section.id, resize),
          onEditCancel: widget.onSectionEditCancel == null
              ? null
              : () => widget.onSectionEditCancel!(section.id),
          onRename: widget.onSectionRename == null
              ? null
              : (name) => widget.onSectionRename!(section.id, name),
          onColorSelected: widget.onSectionColorSelected == null
              ? null
              : (color) => widget.onSectionColorSelected!(section.id, color),
          onDelete: widget.onSectionDelete == null
              ? null
              : () => widget.onSectionDelete!(section.id),
        ),
      ),
    );
  }
}

double _markerFlagWidth(String name, TextDirection direction) {
  final painter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    ),
    maxLines: 1,
    textDirection: direction,
  )..layout(maxWidth: 94);
  return math.max(34, math.min(112, painter.width + 30));
}

class _TimelineSectionStrip extends StatefulWidget {
  const _TimelineSectionStrip({
    required this.section,
    required this.isSelected,
    required this.isPreview,
    required this.pixelsPerSecond,
    required this.onSelect,
    required this.onSeek,
    required this.onEditStart,
    required this.onMovePreview,
    required this.onStartResizePreview,
    required this.onEndResizePreview,
    required this.onEditEnd,
    required this.onEditCancel,
    required this.onRename,
    required this.onColorSelected,
    required this.onDelete,
  });
  final TimelineSection section;
  final bool isSelected;
  final bool isPreview;
  final double pixelsPerSecond;
  final VoidCallback? onSelect;
  final VoidCallback onSeek;
  final VoidCallback? onEditStart;
  final ValueChanged<double>? onMovePreview;
  final ValueChanged<double>? onStartResizePreview;
  final ValueChanged<double>? onEndResizePreview;
  final ValueChanged<bool>? onEditEnd;
  final VoidCallback? onEditCancel;
  final ValueChanged<String>? onRename;
  final ValueChanged<int>? onColorSelected;
  final VoidCallback? onDelete;
  @override
  State<_TimelineSectionStrip> createState() => _TimelineSectionStripState();
}

class _TimelineSectionStripState extends State<_TimelineSectionStrip> {
  final MenuController _menuController = MenuController();
  double _dragStartGlobalX = 0;
  double _originalStart = 0;
  double _originalEnd = 0;

  void _prepare(DragDownDetails details) {
    _dragStartGlobalX = details.globalPosition.dx;
    _originalStart = widget.section.startTime;
    _originalEnd = widget.section.endTime;
  }

  double _delta(DragUpdateDetails details) =>
      (details.globalPosition.dx - _dragStartGlobalX) / widget.pixelsPerSecond;
  void _openProperties() {
    widget.onSelect?.call();
    if (!_menuController.isOpen) _menuController.open();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _menuController,
      useRootOverlay: true,
      consumeOutsideTap: true,
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        SectionPropertiesPopover(
          key: const ValueKey('section-properties-popover'),
          section: widget.section,
          onRename: widget.onRename ?? (_) {},
          onColorSelected: widget.onColorSelected ?? (_) {},
          onDelete: () {
            _menuController.close();
            widget.onDelete?.call();
          },
        ),
      ],
      builder: (context, controller, child) => Stack(
        fit: StackFit.expand,
        children: [
          DawInteractionHint(
            data: DawInteractionHints.sectionNamed(widget.section.name),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onSelect?.call();
                  widget.onSeek();
                },
                onDoubleTap: _openProperties,
                onHorizontalDragDown: _prepare,
                onHorizontalDragStart: (_) {
                  widget.onSelect?.call();
                  widget.onEditStart?.call();
                },
                onHorizontalDragUpdate: (d) => widget.onMovePreview?.call(
                  math.max(0, _originalStart + _delta(d)),
                ),
                onHorizontalDragEnd: (_) => widget.onEditEnd?.call(false),
                onHorizontalDragCancel: widget.onEditCancel,
                child: _SectionSurface(
                  section: widget.section,
                  isSelected: widget.isSelected,
                  isPreview: widget.isPreview,
                  color: Color(widget.section.colorArgb),
                ),
              ),
            ),
          ),
          if (widget.isSelected) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _SectionResizeHandle(
                handleKey: const ValueKey('section-left-handle'),
                onDown: _prepare,
                onStart: widget.onEditStart,
                onUpdate: (d) => widget.onStartResizePreview?.call(
                  math.max(0, _originalStart + _delta(d)),
                ),
                onEnd: () => widget.onEditEnd?.call(true),
                onCancel: widget.onEditCancel,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _SectionResizeHandle(
                handleKey: const ValueKey('section-right-handle'),
                onDown: _prepare,
                onStart: widget.onEditStart,
                onUpdate: (d) => widget.onEndResizePreview?.call(
                  math.max(0, _originalEnd + _delta(d)),
                ),
                onEnd: () => widget.onEditEnd?.call(true),
                onCancel: widget.onEditCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionResizeHandle extends StatelessWidget {
  const _SectionResizeHandle({
    required this.handleKey,
    required this.onDown,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });
  final Key handleKey;
  final GestureDragDownCallback onDown;
  final VoidCallback? onStart;
  final GestureDragUpdateCallback onUpdate;
  final VoidCallback onEnd;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: onDown,
      onHorizontalDragStart: (_) => onStart?.call(),
      onHorizontalDragUpdate: onUpdate,
      onHorizontalDragEnd: (_) => onEnd(),
      onHorizontalDragCancel: onCancel,
      child: Container(
        key: handleKey,
        width: 7,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({
    required this.section,
    required this.isSelected,
    required this.isPreview,
    required this.color,
  });
  final TimelineSection section;
  final bool isSelected;
  final bool isPreview;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSelected ? 9 : 5),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(
            alpha: isPreview
                ? .25
                : isSelected
                ? .29
                : .17,
          ),
          colors.surfaceContainerLow,
        ),
        border: Border(
          top: BorderSide(
            color: color.withValues(alpha: isSelected ? 1 : .72),
            width: isSelected ? 2 : 1.25,
          ),
          bottom: BorderSide(
            color: color.withValues(alpha: isSelected ? 1 : .72),
            width: isSelected ? 2 : 1.25,
          ),
          left: BorderSide(color: color.withValues(alpha: .65)),
          right: BorderSide(color: color.withValues(alpha: .65)),
        ),
      ),
      child: Text(
        section.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurface,
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineMarkerFlag extends StatefulWidget {
  const _TimelineMarkerFlag({
    required this.marker,
    required this.isSelected,
    required this.pixelsPerSecond,
    required this.onSelect,
    required this.onMoveStart,
    required this.onMovePreview,
    required this.onMoveEnd,
    required this.onMoveCancel,
    required this.onRename,
    required this.onColorSelected,
    required this.onDelete,
  });
  final TimelineMarker marker;
  final bool isSelected;
  final double pixelsPerSecond;
  final VoidCallback? onSelect;
  final VoidCallback? onMoveStart;
  final ValueChanged<double>? onMovePreview;
  final VoidCallback? onMoveEnd;
  final VoidCallback? onMoveCancel;
  final ValueChanged<String>? onRename;
  final ValueChanged<int>? onColorSelected;
  final VoidCallback? onDelete;
  @override
  State<_TimelineMarkerFlag> createState() => _TimelineMarkerFlagState();
}

class _TimelineMarkerFlagState extends State<_TimelineMarkerFlag> {
  final MenuController _menuController = MenuController();
  double _dragStartTime = 0;
  double _dragStartGlobalX = 0;
  void _openProperties() {
    widget.onSelect?.call();
    if (!_menuController.isOpen) _menuController.open();
  }

  void _prepareDrag(DragDownDetails d) {
    _dragStartTime = widget.marker.timeSeconds;
    _dragStartGlobalX = d.globalPosition.dx;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _menuController,
      useRootOverlay: true,
      consumeOutsideTap: true,
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        MarkerPropertiesPopover(
          key: const ValueKey('marker-properties-popover'),
          marker: widget.marker,
          onRename: widget.onRename ?? (_) {},
          onColorSelected: widget.onColorSelected ?? (_) {},
          onDelete: () {
            _menuController.close();
            widget.onDelete?.call();
          },
        ),
      ],
      builder: (context, controller, child) => DawInteractionHint(
        data: DawInteractionHints.markerNamed(widget.marker.name),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            onDoubleTap: _openProperties,
            onHorizontalDragDown: _prepareDrag,
            onHorizontalDragStart: (_) => widget.onMoveStart?.call(),
            onHorizontalDragUpdate: (d) => widget.onMovePreview?.call(
              (_dragStartTime +
                      (d.globalPosition.dx - _dragStartGlobalX) /
                          widget.pixelsPerSecond)
                  .clamp(0, double.infinity),
            ),
            onHorizontalDragEnd: (_) => widget.onMoveEnd?.call(),
            onHorizontalDragCancel: widget.onMoveCancel,
            child: Align(
              alignment: Alignment.topLeft,
              child: CustomPaint(
                painter: _MarkerFlagPainter(
                  color: Color(widget.marker.colorArgb),
                  isSelected: widget.isSelected,
                ),
                child: Container(
                  height: 21,
                  constraints: const BoxConstraints(maxWidth: 112),
                  padding: const EdgeInsets.only(left: 12, right: 6, bottom: 2),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.marker.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurface,
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerFlagPainter extends CustomPainter {
  const _MarkerFlagPainter({required this.color, required this.isSelected});
  final Color color;
  final bool isSelected;
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = Color.alphaBlend(
        color.withValues(alpha: isSelected ? .36 : .23),
        Colors.black.withValues(alpha: .82),
      );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1
      ..color = color.withValues(alpha: isSelected ? 1 : .82);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(.5, 1, size.width - 1, size.height - 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, background);
    canvas.drawRRect(rect, border);
    canvas.drawRect(
      Rect.fromLTWH(1, 1.5, 7, size.height - 5),
      Paint()..color = color,
    );
    final pin = Path()
      ..moveTo(2, size.height - 3)
      ..lineTo(8, size.height - 3)
      ..lineTo(5, size.height)
      ..close();
    canvas.drawPath(pin, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerFlagPainter old) =>
      old.color != color || old.isSelected != isSelected;
}
