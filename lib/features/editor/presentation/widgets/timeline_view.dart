import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/audio_clip.dart';
import '../../domain/clip_crossfade.dart';
import '../../domain/daw_track.dart';
import '../../domain/musical_timing.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'clip_properties_popover.dart';
import 'daw_interaction_hint.dart';
import 'track_header.dart';

void _ignoreClipId(String _) {}

class TimelineTrackLane extends StatelessWidget {
  const TimelineTrackLane({
    super.key,
    required this.clips,
    this.trackId,
    this.crossfades,
    this.trackColorValue = 0xFF8468C8,
    required this.gridMetrics,
    required this.selectedClipIds,
    required this.groupMinimumStartSeconds,
    required this.trackIndex,
    required this.orderedTrackColorValues,
    required this.minimumSelectedTrackIndex,
    required this.maximumSelectedTrackIndex,
    required this.clipDragController,
    this.bpm = 120,
    this.timeSignature = defaultTimeSignature,
    this.snapSettings = const SnapSettings(enabled: false),
    required this.onSeek,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
    required this.onGainChangeStart,
    required this.onGainChanged,
    required this.onGainChangeEnd,
    required this.onGainReset,
    required this.onFadeInChangeStart,
    required this.onFadeInChanged,
    required this.onFadeInChangeEnd,
    required this.onFadeInReset,
    required this.onFadeOutChangeStart,
    required this.onFadeOutChanged,
    required this.onFadeOutChangeEnd,
    required this.onFadeOutReset,
    this.onReverseToggle = _ignoreClipId,
    this.onCreateCrossfade,
    this.onRemoveCrossfade,
  });

  final List<AudioClip> clips;
  final String? trackId;
  final List<ClipCrossfadePair>? crossfades;
  final int trackColorValue;
  final TimelineGridMetrics gridMetrics;
  final Set<String> selectedClipIds;
  final double groupMinimumStartSeconds;
  final int trackIndex;
  final List<int> orderedTrackColorValues;
  final int minimumSelectedTrackIndex;
  final int maximumSelectedTrackIndex;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final TimeSignature timeSignature;
  final SnapSettings snapSettings;
  final ValueChanged<double> onSeek;
  final void Function(
    String clipId,
    bool toggle,
    bool preserveExistingIfSelected,
  )
  onSelect;
  final void Function(String clipId, TimelineClipDragResult result)
  onMoveCommitted;
  final void Function(String clipId, TimelineClipDragResult result)
  onTrimCommitted;
  final ValueChanged<String> onGainChangeStart;
  final void Function(String clipId, double value) onGainChanged;
  final ValueChanged<String> onGainChangeEnd;
  final ValueChanged<String> onGainReset;
  final ValueChanged<String> onFadeInChangeStart;
  final void Function(String clipId, double value) onFadeInChanged;
  final ValueChanged<String> onFadeInChangeEnd;
  final ValueChanged<String> onFadeInReset;
  final ValueChanged<String> onFadeOutChangeStart;
  final void Function(String clipId, double value) onFadeOutChanged;
  final ValueChanged<String> onFadeOutChangeEnd;
  final ValueChanged<String> onFadeOutReset;
  final ValueChanged<String> onReverseToggle;
  final VoidCallback? onCreateCrossfade;
  final VoidCallback? onRemoveCrossfade;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transform = gridMetrics.transform;
    final track = DawTrack(
      id: trackId ?? 'timeline-lane',
      name: '',
      clips: clips,
    );
    final allCrossfades = crossfades ?? activeCrossfadePairs(track);
    final activeCrossfades = allCrossfades
        .where((pair) => pair.trackId == track.id)
        .toList();
    final selectedPair = selectedCrossfadePair([track], selectedClipIds);

    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
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
              trackIndex: trackIndex,
              orderedTrackColorValues: orderedTrackColorValues,
              minimumSelectedTrackIndex: minimumSelectedTrackIndex,
              maximumSelectedTrackIndex: maximumSelectedTrackIndex,
              clipDragController: clipDragController,
              bpm: bpm,
              timeSignature: timeSignature,
              snapSettings: snapSettings,
              crossfades: allCrossfades,
              onSelect: (toggle, preserveExistingIfSelected) =>
                  onSelect(clip.id, toggle, preserveExistingIfSelected),
              onMoveCommitted: (result) => onMoveCommitted(clip.id, result),
              onTrimCommitted: (result) => onTrimCommitted(clip.id, result),
              onGainChangeStart: () => onGainChangeStart(clip.id),
              onGainChanged: (value) => onGainChanged(clip.id, value),
              onGainChangeEnd: () => onGainChangeEnd(clip.id),
              onGainReset: () => onGainReset(clip.id),
              onFadeInChangeStart: () => onFadeInChangeStart(clip.id),
              onFadeInChanged: (value) => onFadeInChanged(clip.id, value),
              onFadeInChangeEnd: () => onFadeInChangeEnd(clip.id),
              onFadeInReset: () => onFadeInReset(clip.id),
              onFadeOutChangeStart: () => onFadeOutChangeStart(clip.id),
              onFadeOutChanged: (value) => onFadeOutChanged(clip.id, value),
              onFadeOutChangeEnd: () => onFadeOutChangeEnd(clip.id),
              onFadeOutReset: () => onFadeOutReset(clip.id),
              onReverseToggle: () => onReverseToggle(clip.id),
            ),
          ValueListenableBuilder<TimelineClipDragState?>(
            valueListenable: clipDragController,
            builder: (context, dragState, _) {
              final dragUpdates = dragState?.crossfadeUpdates ?? const [];
              return Positioned.fill(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final pair in activeCrossfades)
                      ..._crossfadePreviewRegions(
                        pair: pair,
                        dragState: dragState,
                        dragUpdates: dragUpdates,
                        selectedClipIds: selectedClipIds,
                        transform: transform,
                        color: colorScheme.tertiary,
                      ),
                    if (dragState == null &&
                        selectedPair != null &&
                        selectedPair.canCreate)
                      _CrossfadeAction(
                        pair: selectedPair,
                        transform: transform,
                        isActive: selectedPair.isCrossfade,
                        onPressed: selectedPair.isCrossfade
                            ? onRemoveCrossfade
                            : onCreateCrossfade,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CrossfadeRegion extends StatelessWidget {
  const _CrossfadeRegion({
    required this.outgoingClipId,
    required this.incomingClipId,
    required this.overlapStartSeconds,
    required this.overlapDurationSeconds,
    required this.transform,
    required this.color,
    this.verticalOffset = 0,
  });

  final String outgoingClipId;
  final String incomingClipId;
  final double overlapStartSeconds;
  final double overlapDurationSeconds;
  final TimelineTransform transform;
  final Color color;
  final double verticalOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: ValueKey('crossfade-region-$outgoingClipId-$incomingClipId'),
      left: transform.timeToContentX(overlapStartSeconds),
      top: 8,
      bottom: 8,
      width: math.max(transform.timeToContentX(overlapDurationSeconds), 1),
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CrossfadeRegionPainter(
              color: color,
              surfaceColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _crossfadePreviewRegions({
  required ClipCrossfadePair pair,
  required TimelineClipDragState? dragState,
  required List<CrossfadeDragUpdate> dragUpdates,
  required Set<String> selectedClipIds,
  required TimelineTransform transform,
  required Color color,
}) {
  CrossfadeDragUpdate? linkedUpdate;
  for (final update in dragUpdates) {
    if (update.snapshot.outgoingClipId == pair.outgoingClip.id &&
        update.snapshot.incomingClipId == pair.incomingClip.id) {
      linkedUpdate = update;
      break;
    }
  }
  if (linkedUpdate != null) {
    if (!linkedUpdate.isActive) {
      return const [];
    }
    final bothMove =
        linkedUpdate.snapshot.outgoingMoves &&
        linkedUpdate.snapshot.incomingMoves;
    return [
      _CrossfadeRegion(
        outgoingClipId: pair.outgoingClip.id,
        incomingClipId: pair.incomingClip.id,
        overlapStartSeconds: linkedUpdate.overlapStartSeconds,
        overlapDurationSeconds: linkedUpdate.overlapDurationSeconds,
        transform: transform,
        color: color,
        verticalOffset: bothMove && dragState != null
            ? dragState.trackDelta * trackHeight
            : 0,
      ),
    ];
  }

  final groupMoves =
      dragState?.mode == TimelineClipDragMode.move &&
      selectedClipIds.contains(dragState!.clipId);
  final bothSelected =
      selectedClipIds.contains(pair.outgoingClip.id) &&
      selectedClipIds.contains(pair.incomingClip.id);
  final translateWithGroup = groupMoves && bothSelected;
  return [
    _CrossfadeRegion(
      outgoingClipId: pair.outgoingClip.id,
      incomingClipId: pair.incomingClip.id,
      overlapStartSeconds:
          pair.overlapStartSeconds +
          (translateWithGroup ? dragState.moveDeltaSeconds : 0),
      overlapDurationSeconds: pair.overlapDurationSeconds,
      transform: transform,
      color: color,
      verticalOffset: translateWithGroup
          ? dragState.trackDelta * trackHeight
          : 0,
    ),
  ];
}

class _CrossfadeAction extends StatelessWidget {
  const _CrossfadeAction({
    required this.pair,
    required this.transform,
    required this.isActive,
    required this.onPressed,
  });

  final ClipCrossfadePair pair;
  final TimelineTransform transform;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final overlapLeft = transform.timeToContentX(pair.overlapStartSeconds);
    final overlapWidth = math.max(
      transform.timeToContentX(pair.overlapDurationSeconds),
      1,
    );
    final buttonWidth = isActive ? 92.0 : 66.0;
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey(
        'crossfade-action-${pair.outgoingClip.id}-${pair.incomingClip.id}',
      ),
      left: overlapLeft + overlapWidth / 2 - buttonWidth / 2,
      top: 12,
      width: buttonWidth,
      height: 24,
      child: Material(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.18),
          colorScheme.surfaceContainerHighest,
        ),
        elevation: 3,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        shape: StadiumBorder(
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.72)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            isActive ? 'remove-crossfade-button' : 'create-crossfade-button',
          ),
          onTap: onPressed,
          child: Center(
            child: Text(
              isActive ? 'REMOVE XFADE' : 'XFADE',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossfadeRegionPainter extends CustomPainter {
  const _CrossfadeRegionPainter({
    required this.color,
    required this.surfaceColor,
  });

  final Color color;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.13),
    );

    const inset = 4.0;
    final top = math.min(inset, size.height / 2);
    final bottom = math.max(top, size.height - inset);
    final halo = Paint()
      ..color = surfaceColor.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final downStart = Offset(0, top);
    final downEnd = Offset(size.width, bottom);
    final upStart = Offset(0, bottom);
    final upEnd = Offset(size.width, top);
    canvas
      ..drawLine(downStart, downEnd, halo)
      ..drawLine(upStart, upEnd, halo)
      ..drawLine(downStart, downEnd, line)
      ..drawLine(upStart, upEnd, line);

    final marker = Paint()..color = color;
    for (final point in [downStart, downEnd, upStart, upEnd]) {
      canvas.drawCircle(point, 2.4, marker);
    }
  }

  @override
  bool shouldRepaint(covariant _CrossfadeRegionPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.surfaceColor != surfaceColor;
}

class _TimelineAudioClip extends StatefulWidget {
  const _TimelineAudioClip({
    super.key,
    required this.clip,
    required this.trackColor,
    required this.transform,
    required this.selectedClipIds,
    required this.groupMinimumStartSeconds,
    required this.trackIndex,
    required this.orderedTrackColorValues,
    required this.minimumSelectedTrackIndex,
    required this.maximumSelectedTrackIndex,
    required this.clipDragController,
    required this.bpm,
    required this.timeSignature,
    required this.snapSettings,
    required this.crossfades,
    required this.onSelect,
    required this.onMoveCommitted,
    required this.onTrimCommitted,
    required this.onGainChangeStart,
    required this.onGainChanged,
    required this.onGainChangeEnd,
    required this.onGainReset,
    required this.onFadeInChangeStart,
    required this.onFadeInChanged,
    required this.onFadeInChangeEnd,
    required this.onFadeInReset,
    required this.onFadeOutChangeStart,
    required this.onFadeOutChanged,
    required this.onFadeOutChangeEnd,
    required this.onFadeOutReset,
    required this.onReverseToggle,
  });

  final AudioClip clip;
  final Color trackColor;
  final TimelineTransform transform;
  final Set<String> selectedClipIds;
  final double groupMinimumStartSeconds;
  final int trackIndex;
  final List<int> orderedTrackColorValues;
  final int minimumSelectedTrackIndex;
  final int maximumSelectedTrackIndex;
  final TimelineClipDragController clipDragController;
  final double bpm;
  final TimeSignature timeSignature;
  final SnapSettings snapSettings;
  final List<ClipCrossfadePair> crossfades;
  final void Function(bool toggle, bool preserveExistingIfSelected) onSelect;
  final ValueChanged<TimelineClipDragResult> onMoveCommitted;
  final ValueChanged<TimelineClipDragResult> onTrimCommitted;
  final VoidCallback onGainChangeStart;
  final ValueChanged<double> onGainChanged;
  final VoidCallback onGainChangeEnd;
  final VoidCallback onGainReset;
  final VoidCallback onFadeInChangeStart;
  final ValueChanged<double> onFadeInChanged;
  final VoidCallback onFadeInChangeEnd;
  final VoidCallback onFadeInReset;
  final VoidCallback onFadeOutChangeStart;
  final ValueChanged<double> onFadeOutChanged;
  final VoidCallback onFadeOutChangeEnd;
  final VoidCallback onFadeOutReset;
  final VoidCallback onReverseToggle;

  @override
  State<_TimelineAudioClip> createState() => _TimelineAudioClipState();
}

class _TimelineAudioClipState extends State<_TimelineAudioClip> {
  static const double _moveStartThreshold = 3;

  int? _pendingMovePointer;
  double? _pendingMoveGlobalX;
  double? _pendingMoveGlobalY;
  bool _pendingClickShouldCollapseSelection = false;

  AudioClip get clip => widget.clip;
  Color get trackColor => widget.trackColor;
  TimelineTransform get transform => widget.transform;
  bool get isSelected => widget.selectedClipIds.contains(clip.id);
  TimelineClipDragController get clipDragController =>
      widget.clipDragController;
  double get bpm => widget.bpm;
  TimeSignature get timeSignature => widget.timeSignature;
  SnapSettings get snapSettings => widget.snapSettings;
  void Function(bool toggle, bool preserveExistingIfSelected) get onSelect =>
      widget.onSelect;
  ValueChanged<TimelineClipDragResult> get onMoveCommitted =>
      widget.onMoveCommitted;
  ValueChanged<TimelineClipDragResult> get onTrimCommitted =>
      widget.onTrimCommitted;
  VoidCallback get onGainChangeStart => widget.onGainChangeStart;
  ValueChanged<double> get onGainChanged => widget.onGainChanged;
  VoidCallback get onGainChangeEnd => widget.onGainChangeEnd;
  VoidCallback get onGainReset => widget.onGainReset;
  VoidCallback get onFadeInChangeStart => widget.onFadeInChangeStart;
  ValueChanged<double> get onFadeInChanged => widget.onFadeInChanged;
  VoidCallback get onFadeInChangeEnd => widget.onFadeInChangeEnd;
  VoidCallback get onFadeInReset => widget.onFadeInReset;
  VoidCallback get onFadeOutChangeStart => widget.onFadeOutChangeStart;
  ValueChanged<double> get onFadeOutChanged => widget.onFadeOutChanged;
  VoidCallback get onFadeOutChangeEnd => widget.onFadeOutChangeEnd;
  VoidCallback get onFadeOutReset => widget.onFadeOutReset;
  VoidCallback get onReverseToggle => widget.onReverseToggle;

  @override
  Widget build(BuildContext context) {
    void commitDrag(int pointer) {
      final result = clipDragController.end(pointer);
      if (!(result?.didChange ?? false)) {
        return;
      }

      switch (result!.mode) {
        case TimelineClipDragMode.move:
          onMoveCommitted(result);
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
        pointerGlobalY: event.position.dy,
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
            _pendingMoveGlobalY == null ||
            (event.position -
                        Offset(_pendingMoveGlobalX!, _pendingMoveGlobalY!))
                    .distance <
                _moveStartThreshold) {
          return;
        }
        clipDragController.begin(
          pointer: event.pointer,
          clipId: clip.id,
          pointerGlobalX: _pendingMoveGlobalX!,
          pointerGlobalY: _pendingMoveGlobalY!,
          anchorTrackIndex: widget.trackIndex,
          minimumSelectedTrackIndex: widget.minimumSelectedTrackIndex,
          maximumSelectedTrackIndex: widget.maximumSelectedTrackIndex,
          trackCount: widget.orderedTrackColorValues.length,
          clipStartSeconds: clip.timelineStartSeconds,
          sourceStartSeconds: clip.sourceStartSeconds,
          clipDurationSeconds: clip.clipDurationSeconds,
          sourceAudioDurationSeconds: clip.sourceAudioDurationSeconds,
          pixelsPerSecond: transform.scale.pixelsPerSecond,
          bpm: bpm,
          timeSignature: timeSignature,
          snapSettings: snapSettings,
          minimumMoveAnchorStartSeconds:
              clip.timelineStartSeconds - widget.groupMinimumStartSeconds,
          crossfadeSnapshots: _crossfadeSnapshotsForMove(),
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
        final destinationTrackIndex =
            widget.trackIndex +
            (isGroupMoveDragging ? dragState.trackDelta : 0);
        final visualTrackColor =
            isGroupMoveDragging &&
                destinationTrackIndex >= 0 &&
                destinationTrackIndex < widget.orderedTrackColorValues.length
            ? Color(widget.orderedTrackColorValues[destinationTrackIndex])
            : trackColor;
        var visualFadeInDurationSeconds = clip.fadeInDurationSeconds;
        var visualFadeOutDurationSeconds = clip.fadeOutDurationSeconds;
        for (final update in dragState?.crossfadeUpdates ?? const []) {
          if (update.snapshot.outgoingClipId == clip.id) {
            visualFadeOutDurationSeconds = update.isActive
                ? update.overlapDurationSeconds
                : 0;
          }
          if (update.snapshot.incomingClipId == clip.id) {
            visualFadeInDurationSeconds = update.isActive
                ? update.overlapDurationSeconds
                : 0;
          }
        }

        return Positioned(
          left: transform.timeToContentX(visualStartSeconds),
          top: 8,
          bottom: 8,
          width: renderedClipWidth,
          child: Transform.translate(
            offset: Offset(
              0,
              isGroupMoveDragging ? dragState.trackDelta * trackHeight : 0,
            ),
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
                    borderRadius: BorderRadius.circular(7),
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
                  onGainChangeStart: (_) => onGainChangeStart(),
                  onGainChanged: onGainChanged,
                  onGainChangeEnd: (_) => onGainChangeEnd(),
                  onGainReset: onGainReset,
                  onFadeInChangeStart: (_) => onFadeInChangeStart(),
                  onFadeInChanged: onFadeInChanged,
                  onFadeInChangeEnd: (_) => onFadeInChangeEnd(),
                  onFadeInReset: onFadeInReset,
                  onFadeOutChangeStart: (_) => onFadeOutChangeStart(),
                  onFadeOutChanged: onFadeOutChanged,
                  onFadeOutChangeEnd: (_) => onFadeOutChangeEnd(),
                  onFadeOutReset: onFadeOutReset,
                  onReverseToggle: onReverseToggle,
                ),
              ],
              builder: (context, menuController, child) => Stack(
                children: [
                  Positioned.fill(
                    child: DawInteractionHint(
                      data: DawInteractionHints.audioClip,
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
                            _pendingMoveGlobalY = event.position.dy;
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
                              isReversed: clip.isReversed,
                              showReverseIndicator: renderedClipWidth >= 54,
                              gainDb: clip.gainDb,
                              showGainIndicator: renderedClipWidth >= 135,
                              fadeInDurationSeconds:
                                  visualFadeInDurationSeconds,
                              fadeOutDurationSeconds:
                                  visualFadeOutDurationSeconds,
                              trackColor: visualTrackColor,
                              isSelected: isSelected,
                              isDragging: isDragging,
                            ),
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
    _pendingMoveGlobalY = null;
  }

  List<CrossfadeDragSnapshot> _crossfadeSnapshotsForMove() {
    final movingClipIds = widget.selectedClipIds.contains(clip.id)
        ? widget.selectedClipIds
        : {clip.id};
    return [
      for (final pair in widget.crossfades)
        if (movingClipIds.contains(pair.outgoingClip.id) ||
            movingClipIds.contains(pair.incomingClip.id))
          CrossfadeDragSnapshot.fromPair(pair, movingClipIds: movingClipIds),
    ];
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
      timeSignature: timeSignature,
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
    required this.isReversed,
    required this.showReverseIndicator,
    required this.gainDb,
    required this.showGainIndicator,
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
  final bool isReversed;
  final bool showReverseIndicator;
  final double gainDb;
  final bool showGainIndicator;
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
                    isReversed: isReversed,
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
              right: showGainIndicator ? 62 : null,
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
                child: Row(
                  children: [
                    if (isReversed && showReverseIndicator) ...[
                      Icon(
                        Icons.swap_horiz_rounded,
                        key: const ValueKey('clip-reverse-indicator'),
                        size: 14,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        fileName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showGainIndicator && gainDb != defaultClipGainDb) ...[
                      const SizedBox(width: 5),
                      Text(
                        '${gainDb > 0 ? '+' : ''}${gainDb.toStringAsFixed(1)} dB',
                        key: const ValueKey('clip-gain-indicator'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
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
    required this.isReversed,
    required this.color,
  });

  final List<double> peaks;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double sourceAudioDurationSeconds;
  final bool isReversed;
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
      final sourceColumn = isReversed ? columnCount - column - 1 : column;
      final startIndex =
          visibleStartIndex +
          (sourceColumn * visiblePeakCount / columnCount).floor();
      final endIndex = math.min(
        visibleStartIndex +
            (((sourceColumn + 1) * visiblePeakCount / columnCount).ceil()),
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
        oldDelegate.isReversed != isReversed ||
        oldDelegate.color != color;
  }
}
