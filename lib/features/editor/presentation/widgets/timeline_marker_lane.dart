import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/timeline_marker.dart';
import '../../domain/timeline_scale.dart';
import 'marker_properties_popover.dart';

class TimelineMarkerLane extends StatelessWidget {
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
  });

  static const double height = 20;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordered = [
      ...markers.where((marker) => marker.id != selectedMarkerId),
      ...markers.where((marker) => marker.id == selectedMarkerId),
    ];
    final markerWidths = {
      for (final marker in markers)
        marker.id: _markerFlagWidth(marker.name, Directionality.of(context)),
    };
    return GestureDetector(
      key: const ValueKey('timeline-marker-lane'),
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: onAddMarker == null
          ? null
          : (details) {
              final x = details.localPosition.dx;
              final hitsExistingMarker = markers.any((marker) {
                final markerX = gridMetrics.transform.timeToContentX(
                  marker.timeSeconds,
                );
                return x >= markerX - 5 &&
                    x <= markerX - 5 + markerWidths[marker.id]!;
              });
              if (!hitsExistingMarker) {
                onAddMarker!(gridMetrics.transform.contentXToTime(x));
              }
            },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: gridMetrics.transform.timeToContentX(playheadSeconds) - 1,
              top: 0,
              bottom: 0,
              width: 2,
              child: IgnorePointer(
                child: ColoredBox(color: colorScheme.tertiary),
              ),
            ),
            for (final marker in ordered)
              Positioned(
                key: ValueKey('timeline-marker-${marker.id}'),
                left:
                    gridMetrics.transform.timeToContentX(marker.timeSeconds) -
                    5,
                top: 0,
                width: markerWidths[marker.id],
                height: height,
                child: _TimelineMarkerFlag(
                  marker: marker,
                  isSelected: marker.id == selectedMarkerId,
                  pixelsPerSecond: gridMetrics.scale.pixelsPerSecond,
                  onSelect: onSelectMarker == null
                      ? null
                      : () {
                          onSelectMarker!(marker.id);
                          onSeek(marker.timeSeconds);
                        },
                  onMoveStart: onMoveStart == null
                      ? null
                      : () => onMoveStart!(marker.id),
                  onMovePreview: onMovePreview == null
                      ? null
                      : (time) => onMovePreview!(marker.id, time),
                  onMoveEnd: onMoveEnd == null
                      ? null
                      : () => onMoveEnd!(marker.id),
                  onMoveCancel: onMoveCancel == null
                      ? null
                      : () => onMoveCancel!(marker.id),
                  onRename: onRename == null
                      ? null
                      : (name) => onRename!(marker.id, name),
                  onColorSelected: onColorSelected == null
                      ? null
                      : (color) => onColorSelected!(marker.id, color),
                  onDelete: onDelete == null
                      ? null
                      : () => onDelete!(marker.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

double _markerFlagWidth(String name, TextDirection textDirection) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    ),
    maxLines: 1,
    textDirection: textDirection,
  )..layout(maxWidth: 94);
  return math.max(34, math.min(112, textPainter.width + 30));
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
    if (!_menuController.isOpen) {
      _menuController.open();
    }
  }

  void _prepareDrag(DragDownDetails details) {
    _dragStartTime = widget.marker.timeSeconds;
    _dragStartGlobalX = details.globalPosition.dx;
  }

  void _startDrag(DragStartDetails _) {
    widget.onMoveStart?.call();
  }

  void _updateDrag(DragUpdateDetails details) {
    widget.onMovePreview?.call(
      (_dragStartTime +
              (details.globalPosition.dx - _dragStartGlobalX) /
                  widget.pixelsPerSecond)
          .clamp(0, double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = Color(widget.marker.colorArgb);
    return MenuAnchor(
      controller: _menuController,
      useRootOverlay: true,
      consumeOutsideTap: true,
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: colorScheme.outlineVariant),
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
      builder: (context, controller, child) => MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelect,
          onDoubleTap: _openProperties,
          onHorizontalDragDown: _prepareDrag,
          onHorizontalDragStart: _startDrag,
          onHorizontalDragUpdate: _updateDrag,
          onHorizontalDragEnd: (_) => widget.onMoveEnd?.call(),
          onHorizontalDragCancel: widget.onMoveCancel,
          child: Align(
            alignment: Alignment.topLeft,
            child: CustomPaint(
              painter: _MarkerFlagPainter(
                color: markerColor,
                isSelected: widget.isSelected,
              ),
              child: Container(
                height: 19,
                constraints: const BoxConstraints(maxWidth: 112),
                padding: const EdgeInsets.only(left: 12, right: 6, bottom: 2),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.marker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
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
        color.withValues(alpha: isSelected ? 0.36 : 0.23),
        Colors.black.withValues(alpha: 0.82),
      );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1
      ..color = color.withValues(alpha: isSelected ? 1 : 0.82);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 1, size.width - 1, size.height - 4),
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
  bool shouldRepaint(covariant _MarkerFlagPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}
