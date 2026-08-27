import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/audio_clip.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'clip_properties_popover.dart';
import 'track_header.dart';

class TimelineTrackLane extends StatelessWidget {
  const TimelineTrackLane({
    super.key,
    required this.clips,
    this.trackColorValue = 0xFF8468C8,
    required this.gridMetrics,
    required this.selectedClipIds,
    required this.groupMinimumStartSeconds,
    required this.clipDragController,
    this.bpm = 120,
    this.snapSettings = const SnapSettings(enabled: false),
    required this.onSeek,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
    required this.onFadeInChangeStart,
    required this.onFadeInChanged,
    required this.onFadeInChangeEnd,
    required this.onFadeInReset,
    required this.onFadeOutChangeStart,
    required this.onFadeOutChanged,
    required this.onFadeOutChangeEnd,
    required this.onFadeOutReset,
  });

  final List<AudioClip> clips;
  final int trackColorValue;
  final TimelineGridMetrics gridMetrics;
  final Set<String> selectedClipIds;
  final double groupMinimumStartSeconds;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final SnapSettings snapSettings;
  final ValueChanged<double> onSeek;
  final void Function(
    String clipId,
    bool toggle,
    bool preserveExistingIfSelected,
  )
  onSelect;
  final void Function(String clipId, double startSeconds) onMoveCommitted;
  final void Function(String clipId, TimelineClipDragResult result)
  onTrimCommitted;
  final ValueChanged<String> onFadeInChangeStart;
  final void Function(String clipId, double value) onFadeInChanged;
  final ValueChanged<String> onFadeInChangeEnd;
  final ValueChanged<String> onFadeInReset;
  final ValueChanged<String> onFadeOutChangeStart;
  final void Function(String clipId, double value) onFadeOutChanged;
  final ValueChanged<String> onFadeOutChangeEnd;
  final ValueChanged<String> onFadeOutReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transform = gridMetrics.transform;

    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                onSeek(transform.contentXToTime(details.localPosition.dx));
              },
              child: const SizedBox.expand(),
            ),
          ),
          for (final clip in clips)
            _TimelineAudioClip(
              key: ValueKey(clip.id),
              clip: clip,
              trackColor: Color(trackColorValue),
              transform: transform,
              selectedClipIds: selectedClipIds,
              groupMinimumStartSeconds: groupMinimumStartSeconds,
              clipDragController: clipDragController,
              bpm: bpm,
              snapSettings: snapSettings,
              onSelect: (toggle, preserveExistingIfSelected) =>
                  onSelect(clip.id, toggle, preserveExistingIfSelected),
              onMoveCommitted: (start) => onMoveCommitted(clip.id, start),
              onTrimCommitted: (result) => onTrimCommitted(clip.id, result),
              onFadeInChangeStart: () => onFadeInChangeStart(clip.id),
              onFadeInChanged: (value) => onFadeInChanged(clip.id, value),
              onFadeInChangeEnd: () => onFadeInChangeEnd(clip.id),
              onFadeInReset: () => onFadeInReset(clip.id),
              onFadeOutChangeStart: () => onFadeOutChangeStart(clip.id),
              onFadeOutChanged: (value) => onFadeOutChanged(clip.id, value),
              onFadeOutChangeEnd: () => onFadeOutChangeEnd(clip.id),
              onFadeOutReset: () => onFadeOutReset(clip.id),
            ),
        ],
      ),
    );
  }
}

class _TimelineAudioClip extends StatefulWidget {
  const _TimelineAudioClip({
    super.key,
    required this.clip,
    required this.trackColor,
    required this.transform,
    required this.selectedClipIds,
    required this.groupMinimumStartSeconds,
    required this.clipDragController,
    required this.bpm,
    required this.snapSettings,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
    required this.onFadeInChangeStart,
    required this.onFadeInChanged,
    required this.onFadeInChangeEnd,
    required this.onFadeInReset,
    required this.onFadeOutChangeStart,
    required this.onFadeOutChanged,
    required this.onFadeOutChangeEnd,
    required this.onFadeOutReset,
  });

  final AudioClip clip;
  final Color trackColor;
  final TimelineTransform transform;
  final Set<String> selectedClipIds;
  final double groupMinimumStartSeconds;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final SnapSettings snapSettings;
  final void Function(bool toggle, bool preserveExistingIfSelected) onSelect;
  final ValueChanged<double> onMoveCommitted;
  final ValueChanged<TimelineClipDragResult> onTrimCommitted;
  final VoidCallback onFadeInChangeStart;
  final ValueChanged<double> onFadeInChanged;
  final VoidCallback onFadeInChangeEnd;
  final VoidCallback onFadeInReset;
  final VoidCallback onFadeOutChangeStart;
  final ValueChanged<double> onFadeOutChanged;
  final VoidCallback onFadeOutChangeEnd;
  final VoidCallback onFadeOutReset;

  @override
  State<_TimelineAudioClip> createState() => _TimelineAudioClipState();
}

class _TimelineAudioClipState extends State<_TimelineAudioClip> {
  static const double _moveStartThreshold = 3;

  int? _pendingMovePointer;
  double? _pendingMoveGlobalX;
  bool _pendingClickShouldCollapseSelection = false;

  AudioClip get clip => widget.clip;
  Color get trackColor => widget.trackColor;
  TimelineTransform get transform => widget.transform;
  bool get isSelected => widget.selectedClipIds.contains(clip.id);
  TimelineClipDragController get clipDragController =>
      widget.clipDragController;
  double get bpm => widget.bpm;
  SnapSettings get snapSettings => widget.snapSettings;
  void Function(bool toggle, bool preserveExistingIfSelected) get onSelect =>
      widget.onSelect;
  ValueChanged<double> get onMoveCommitted => widget.onMoveCommitted;
  ValueChanged<TimelineClipDragResult> get onTrimCommitted =>
      widget.onTrimCommitted;
  VoidCallback get onFadeInChangeStart => widget.onFadeInChangeStart;
  ValueChanged<double> get onFadeInChanged => widget.onFadeInChanged;
  VoidCallback get onFadeInChangeEnd => widget.onFadeInChangeEnd;
  VoidCallback get onFadeInReset => widget.onFadeInReset;
  VoidCallback get onFadeOutChangeStart => widget.onFadeOutChangeStart;
  ValueChanged<double> get onFadeOutChanged => widget.onFadeOutChanged;
  VoidCallback get onFadeOutChangeEnd => widget.onFadeOutChangeEnd;
  VoidCallback get onFadeOutReset => widget.onFadeOutReset;

  @override
  Widget build(BuildContext context) {
    void commitDrag(int pointer) {
      final result = clipDragController.end(pointer);
      if (!(result?.didChange ?? false)) {
        return;
      }

      switch (result!.mode) {
        case TimelineClipDragMode.move:
          onMoveCommitted(result.startSeconds);
          break;
        case TimelineClipDragMode.trimStart:
        case TimelineClipDragMode.trimEnd:
          onTrimCommitted(result);
          break;
      }
    }

    void updateDrag(PointerMoveEvent event) {
      if ((event.buttons & kPrimaryMouseButton) == 0) {
        commitDrag(event.pointer);
        return;
      }
      clipDragController.update(
        pointer: event.pointer,
        pointerGlobalX: event.position.dx,
        bypassSnap: HardwareKeyboard.instance.isAltPressed,
      );
    }

    void updateClipMove(PointerMoveEvent event) {
      if ((event.buttons & kPrimaryMouseButton) == 0) {
        commitDrag(event.pointer);
        _clearPendingMove(event.pointer);
        return;
      }

      final activeDrag = clipDragController.value;
      if (activeDrag?.clipId != clip.id) {
        if (_pendingMovePointer != event.pointer ||
            _pendingMoveGlobalX == null ||
            (event.position.dx - _pendingMoveGlobalX!).abs() <
                _moveStartThreshold) {
          return;
        }
        clipDragController.begin(
          pointer: event.pointer,
          clipId: clip.id,
          pointerGlobalX: _pendingMoveGlobalX!,
          clipStartSeconds: clip.timelineStartSeconds,
          sourceStartSeconds: clip.sourceStartSeconds,
          clipDurationSeconds: clip.clipDurationSeconds,
          sourceAudioDurationSeconds: clip.sourceAudioDurationSeconds,
          pixelsPerSecond: transform.scale.pixelsPerSecond,
          bpm: bpm,
          snapSettings: snapSettings,
          minimumMoveAnchorStartSeconds:
              clip.timelineStartSeconds - widget.groupMinimumStartSeconds,
        );
      }
      updateDrag(event);
    }

    return ValueListenableBuilder<TimelineClipDragState?>(
      valueListenable: clipDragController,
      builder: (context, dragState, child) {
        final isAnchorDragging = dragState?.clipId == clip.id;
        final isGroupMoveDragging =
            dragState?.mode == TimelineClipDragMode.move &&
            widget.selectedClipIds.contains(dragState!.clipId) &&
            isSelected;
        final isDragging = isAnchorDragging || isGroupMoveDragging;
        final visualStartSeconds = isGroupMoveDragging
            ? clip.timelineStartSeconds + dragState.moveDeltaSeconds
            : isAnchorDragging
            ? dragState!.previewStartSeconds
            : clip.timelineStartSeconds;
        final visualSourceStartSeconds = isAnchorDragging
            ? dragState!.previewSourceStartSeconds
            : clip.sourceStartSeconds;
        final visualDurationSeconds = isAnchorDragging
            ? dragState!.clipDurationSeconds
            : clip.clipDurationSeconds;
        final renderedClipWidth = math.max(
          transform.timeToContentX(visualDurationSeconds),
          1.0,
        );
        final trimHitWidth = math.min(12.0, renderedClipWidth / 2);

        return Positioned(
          left: transform.timeToContentX(visualStartSeconds),
          top: 8,
          bottom: 8,
          width: renderedClipWidth,
          child: MenuAnchor(
            useRootOverlay: true,
            consumeOutsideTap: true,
            style: MenuStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              elevation: const WidgetStatePropertyAll(8),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            menuChildren: [
              ClipPropertiesPopover(
                key: const ValueKey('clip-properties-popover'),
                clip: clip,
                onFadeInChangeStart: (_) => onFadeInChangeStart(),
                onFadeInChanged: onFadeInChanged,
                onFadeInChangeEnd: (_) => onFadeInChangeEnd(),
                onFadeInReset: onFadeInReset,
                onFadeOutChangeStart: (_) => onFadeOutChangeStart(),
                onFadeOutChanged: onFadeOutChanged,
                onFadeOutChangeEnd: (_) => onFadeOutChangeEnd(),
                onFadeOutReset: onFadeOutReset,
              ),
            ],
            builder: (context, menuController, child) => Stack(
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    cursor:
                        isDragging &&
                            dragState!.mode == TimelineClipDragMode.move
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if ((event.buttons & kPrimaryMouseButton) == 0) {
                          return;
                        }
                        final toggle =
                            HardwareKeyboard.instance.isControlPressed;
                        _pendingClickShouldCollapseSelection =
                            !toggle &&
                            isSelected &&
                            widget.selectedClipIds.length > 1;
                        onSelect(toggle, !toggle);
                        _pendingMovePointer = event.pointer;
                        _pendingMoveGlobalX = event.position.dx;
                      },
                      onPointerMove: updateClipMove,
                      onPointerUp: (event) {
                        commitDrag(event.pointer);
                        _clearPendingMove(event.pointer);
                      },
                      onPointerCancel: (event) {
                        clipDragController.cancel(event.pointer);
                        _clearPendingMove(event.pointer);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_pendingClickShouldCollapseSelection &&
                              !HardwareKeyboard.instance.isControlPressed) {
                            onSelect(false, false);
                          }
                          _pendingClickShouldCollapseSelection = false;
                        },
                        onDoubleTap: () {
                          if (widget.selectedClipIds.length != 1 ||
                              !isSelected) {
                            return;
                          }
                          menuController.open();
                        },
                        child: _AudioClipSurface(
                          fileName: clip.audio.name,
                          clipDurationSeconds: visualDurationSeconds,
                          sourceStartSeconds: visualSourceStartSeconds,
                          sourceAudioDurationSeconds:
                              clip.sourceAudioDurationSeconds,
                          waveformPeaks: clip.audio.waveformPeaks,
                          fadeInDurationSeconds: clip.fadeInDurationSeconds,
                          fadeOutDurationSeconds: clip.fadeOutDurationSeconds,
                          trackColor: trackColor,
                          isSelected: isSelected,
                          isDragging: isDragging,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: trimHitWidth,
                  child: _TrimHandle(
                    side: TimelineClipDragMode.trimStart,
                    isSelected: isSelected,
                    isActive:
                        isDragging &&
                        dragState!.mode == TimelineClipDragMode.trimStart,
                    onPointerDown: (event) => _beginTrim(
                      event: event,
                      side: TimelineClipDragMode.trimStart,
                    ),
                    onPointerMove: updateDrag,
                    onPointerUp: (event) => commitDrag(event.pointer),
                    onPointerCancel: (event) {
                      clipDragController.cancel(event.pointer);
                    },
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: trimHitWidth,
                  child: _TrimHandle(
                    side: TimelineClipDragMode.trimEnd,
                    isSelected: isSelected,
                    isActive:
                        isDragging &&
                        dragState!.mode == TimelineClipDragMode.trimEnd,
                    onPointerDown: (event) => _beginTrim(
                      event: event,
                      side: TimelineClipDragMode.trimEnd,
                    ),
                    onPointerMove: updateDrag,
                    onPointerUp: (event) => commitDrag(event.pointer),
                    onPointerCancel: (event) {
                      clipDragController.cancel(event.pointer);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearPendingMove(int pointer) {
    if (_pendingMovePointer != pointer) {
      return;
    }
    _pendingMovePointer = null;
    _pendingMoveGlobalX = null;
  }

  void _beginTrim({
    required PointerDownEvent event,
    required TimelineClipDragMode side,
  }) {
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    onSelect(false, false);
    clipDragController.beginTrim(
      pointer: event.pointer,
      clipId: clip.id,
      mode: side,
      pointerGlobalX: event.position.dx,
      clipStartSeconds: clip.timelineStartSeconds,
      sourceStartSeconds: clip.sourceStartSeconds,
      clipDurationSeconds: clip.clipDurationSeconds,
      sourceAudioDurationSeconds: clip.sourceAudioDurationSeconds,
      pixelsPerSecond: transform.scale.pixelsPerSecond,
      bpm: bpm,
      snapSettings: snapSettings,
    );
  }
}

class _TrimHandle extends StatefulWidget {
  const _TrimHandle({
    required this.side,
    required this.isSelected,
    required this.isActive,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final TimelineClipDragMode side;
  final bool isSelected;
  final bool isActive;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showAffordance = _isHovered || widget.isSelected || widget.isActive;
    final alignment = widget.side == TimelineClipDragMode.trimStart
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.onPointerDown,
        onPointerMove: widget.onPointerMove,
        onPointerUp: widget.onPointerUp,
        onPointerCancel: widget.onPointerCancel,
        child: Align(
          alignment: alignment,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: showAffordance
                  ? widget.isActive
                        ? colorScheme.tertiary
                        : colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioClipSurface extends StatelessWidget {
  const _AudioClipSurface({
    required this.fileName,
    required this.clipDurationSeconds,
    required this.sourceStartSeconds,
    required this.sourceAudioDurationSeconds,
    required this.waveformPeaks,
    required this.fadeInDurationSeconds,
    required this.fadeOutDurationSeconds,
    required this.trackColor,
    required this.isSelected,
    required this.isDragging,
  });

  final String fileName;
  final double clipDurationSeconds;
  final double sourceStartSeconds;
  final double sourceAudioDurationSeconds;
  final List<double> waveformPeaks;
  final double fadeInDurationSeconds;
  final double fadeOutDurationSeconds;
  final Color trackColor;
  final bool isSelected;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = Color.alphaBlend(
      trackColor.withValues(alpha: isDragging ? 0.34 : 0.24),
      colorScheme.surfaceContainerHigh,
    );
    final waveformColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.68);
    final fadeContrastColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final identityBorderColor = trackColor.computeLuminance() < 0.035
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.38), trackColor)
        : trackColor.withValues(alpha: 0.9);
    final borderColor = isDragging
        ? colorScheme.tertiary
        : isSelected
        ? colorScheme.onSurface
        : identityBorderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: isDragging || isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : isSelected
            ? [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(alpha: 0.14),
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    peaks: waveformPeaks,
                    sourceStartSeconds: sourceStartSeconds,
                    clipDurationSeconds: clipDurationSeconds,
                    sourceAudioDurationSeconds: sourceAudioDurationSeconds,
                    color: waveformColor,
                  ),
                ),
              ),
            ),
            if (fadeInDurationSeconds > 0 || fadeOutDurationSeconds > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FadeIndicatorPainter(
                      fadeInFraction:
                          fadeInDurationSeconds / clipDurationSeconds,
                      fadeOutFraction:
                          fadeOutDurationSeconds / clipDurationSeconds,
                      lineColor: fadeContrastColor.withValues(
                        alpha: isSelected ? 0.96 : 0.82,
                      ),
                      fillColor: fadeContrastColor.withValues(
                        alpha: isSelected ? 0.13 : 0.09,
                      ),
                      haloColor: backgroundColor.withValues(alpha: 0.92),
                      isSelected: isSelected,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    colorScheme.surface.withValues(alpha: 0.72),
                    backgroundColor,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 5,
              child: Text(
                '${clipDurationSeconds.toStringAsFixed(2)}s',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeIndicatorPainter extends CustomPainter {
  const _FadeIndicatorPainter({
    required this.fadeInFraction,
    required this.fadeOutFraction,
    required this.lineColor,
    required this.fillColor,
    required this.haloColor,
    required this.isSelected,
  });

  final double fadeInFraction;
  final double fadeOutFraction;
  final Color lineColor;
  final Color fillColor;
  final Color haloColor;
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final fadeInWidth = size.width * fadeInFraction.clamp(0.0, 1.0).toDouble();
    final fadeOutWidth =
        size.width * fadeOutFraction.clamp(0.0, 1.0).toDouble();
    const top = 4.0;
    final bottom = math.max(top, size.height - 4);

    final envelope = Path()..moveTo(0, fadeInWidth > 0 ? bottom : top);
    if (fadeInWidth > 0) {
      envelope.lineTo(fadeInWidth, top);
    }
    envelope.lineTo(size.width - fadeOutWidth, top);
    if (fadeOutWidth > 0) {
      envelope.lineTo(size.width, bottom);
    } else {
      envelope.lineTo(size.width, top);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    if (fadeInWidth > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(0, top)
          ..lineTo(fadeInWidth, top)
          ..lineTo(0, bottom)
          ..close(),
        fillPaint,
      );
    }
    if (fadeOutWidth > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width - fadeOutWidth, top)
          ..lineTo(size.width, top)
          ..lineTo(size.width, bottom)
          ..close(),
        fillPaint,
      );
    }

    canvas.drawPath(
      envelope,
      Paint()
        ..color = haloColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 5 : 4.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      envelope,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.6 : 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final markerFill = Paint()..color = lineColor;
    final markerOutline = Paint()
      ..color = haloColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (fadeInFraction > 0) {
      final marker = Offset(fadeInWidth, top);
      canvas.drawCircle(marker, isSelected ? 4 : 3.5, markerOutline);
      canvas.drawCircle(marker, isSelected ? 3 : 2.5, markerFill);
    }
    if (fadeOutFraction > 0) {
      final marker = Offset(size.width - fadeOutWidth, top);
      canvas.drawCircle(marker, isSelected ? 4 : 3.5, markerOutline);
      canvas.drawCircle(marker, isSelected ? 3 : 2.5, markerFill);
    }
  }

  @override
  bool shouldRepaint(covariant _FadeIndicatorPainter oldDelegate) {
    return oldDelegate.fadeInFraction != fadeInFraction ||
        oldDelegate.fadeOutFraction != fadeOutFraction ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.haloColor != haloColor ||
        oldDelegate.isSelected != isSelected;
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.peaks,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.sourceAudioDurationSeconds,
    required this.color,
  });

  final List<double> peaks;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double sourceAudioDurationSeconds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty ||
        sourceAudioDurationSeconds <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final visibleStartIndex =
        (sourceStartSeconds / sourceAudioDurationSeconds * peaks.length)
            .floor()
            .clamp(0, peaks.length - 1);
    final visibleEndIndex =
        ((sourceStartSeconds + clipDurationSeconds) /
                sourceAudioDurationSeconds *
                peaks.length)
            .ceil()
            .clamp(visibleStartIndex + 1, peaks.length);
    final visiblePeakCount = visibleEndIndex - visibleStartIndex;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final maxWaveHeight = size.height * 0.44;
    final columnCount = math.min(
      math.max(size.width.floor(), 1),
      visiblePeakCount,
    );

    for (var column = 0; column < columnCount; column++) {
      final startIndex =
          visibleStartIndex + (column * visiblePeakCount / columnCount).floor();
      final endIndex = math.min(
        visibleStartIndex +
            (((column + 1) * visiblePeakCount / columnCount).ceil()),
        visibleEndIndex,
      );
      var peak = 0.0;

      for (var i = startIndex; i < endIndex; i++) {
        if (peaks[i] > peak) {
          peak = peaks[i];
        }
      }

      final amplitude = peak.clamp(0.0, 1.0) * maxWaveHeight;
      final x = columnCount == 1
          ? size.width / 2
          : column * size.width / (columnCount - 1);
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.sourceStartSeconds != sourceStartSeconds ||
        oldDelegate.clipDurationSeconds != clipDurationSeconds ||
        oldDelegate.sourceAudioDurationSeconds != sourceAudioDurationSeconds ||
        oldDelegate.color != color;
  }
}
