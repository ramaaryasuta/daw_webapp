import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../application/editor_controller.dart';
import '../../application/snap_controller.dart';
import '../../application/tempo_controller.dart';
import '../../domain/audio_clip.dart';
import '../../domain/daw_track.dart';
import '../../domain/timeline_scale.dart';
import '../controllers/timeline_clip_drag_controller.dart';
import 'track_header.dart';
import 'track_lane_background_painter.dart';
import 'timeline_view.dart';

class TrackHeaderList extends ConsumerWidget {
  const TrackHeaderList({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final trackList = ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: editorState.tracks.length,
      itemExtent: trackHeight,
      itemBuilder: (context, index) {
        final track = editorState.tracks[index];

        return TrackHeader(
          key: ValueKey(track.id),
          name: track.name,
          colorValue: track.colorValue,
          volumeDb: track.volumeDb,
          pan: track.pan,
          isMuted: track.isMuted,
          isSolo: track.isSolo,
          isSelected: editorState.selectedTrackId == track.id,
          onTap: () => controller.selectTrack(track.id),
          onRename: (name) => controller.renameTrack(track.id, name),
          onColorEditStarted: () => controller.beginTrackColorChange(track.id),
          onColorPreviewed: (colorValue) =>
              controller.previewTrackColor(track.id, colorValue),
          onColorEditCommitted: () =>
              controller.commitTrackColorChange(track.id),
          onColorEditCancelled: () =>
              controller.cancelTrackColorChange(track.id),
          onColorSelected: (colorValue) =>
              controller.setTrackColor(track.id, colorValue),
          onMutePressed: () => controller.toggleMute(track.id),
          onSoloPressed: () => controller.toggleSolo(track.id),
          onDeletePressed: () => controller.removeTrack(track.id),
          onVolumeChangeStart: (_) => controller.beginVolumeChange(track.id),
          onVolumeChanged: (value) => controller.previewVolume(track.id, value),
          onVolumeChangeEnd: (_) => controller.commitVolumeChange(track.id),
          onVolumeReset: () => controller.resetVolume(track.id),
          onPanChangeStart: (_) => controller.beginPanChange(track.id),
          onPanChanged: (value) => controller.previewPan(track.id, value),
          onPanChangeEnd: (_) => controller.commitPanChange(track.id),
          onPanReset: () => controller.resetPan(track.id),
        );
      },
    );

    return AnimatedBuilder(
      animation: scrollController,
      child: trackList,
      builder: (context, child) {
        final baseColor = colorScheme.surface;
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: TrackLaneBackgroundPainter(
                  baseColor: baseColor,
                  alternateColor: Color.alphaBlend(
                    colorScheme.onSurface.withValues(alpha: 0.018),
                    baseColor,
                  ),
                  separatorColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.72,
                  ),
                  rowHeight: trackHeight,
                  scrollOffset: scrollController.hasClients
                      ? scrollController.offset
                      : 0,
                  devicePixelRatio: devicePixelRatio,
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}

class TimelineTrackList extends ConsumerStatefulWidget {
  const TimelineTrackList({
    super.key,
    required this.viewportKey,
    required this.scrollController,
    required this.gridMetrics,
    required this.clipDragController,
    required this.scrollPhysics,
    required this.onSeek,
  });

  final GlobalKey viewportKey;
  final ScrollController scrollController;
  final TimelineGridMetrics gridMetrics;
  final TimelineClipDragController clipDragController;
  final ScrollPhysics scrollPhysics;
  final ValueChanged<double> onSeek;

  @override
  ConsumerState<TimelineTrackList> createState() => _TimelineTrackListState();
}

class _TimelineTrackListState extends ConsumerState<TimelineTrackList> {
  static const double _marqueeThreshold = 3;

  int? _marqueePointer;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  Set<String> _marqueeBaseSelection = const {};
  Set<String> _marqueePreviewSelection = const {};
  bool _marqueeToggle = false;
  bool _marqueeHasDragged = false;

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(
      editorControllerProvider.select(
        (state) => _TimelineTracksSnapshot(state.tracks),
      ),
    );
    final selectedClipIds = ref.watch(
      editorControllerProvider.select((state) => state.selectedClipIds),
    );
    final bpm = ref.watch(tempoControllerProvider.select((state) => state.bpm));
    final snapSettings = ref.watch(snapControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final effectiveSelection = _marqueePointer == null
        ? selectedClipIds
        : _marqueePreviewSelection;
    final selectedStarts = [
      for (final track in tracks.values)
        for (final clip in track.clips)
          if (effectiveSelection.contains(clip.id)) clip.timelineStartSeconds,
    ];
    final groupMinimumStartSeconds = selectedStarts.isEmpty
        ? 0.0
        : selectedStarts.reduce(math.min);
    final selectedTrackIndices = [
      for (var index = 0; index < tracks.values.length; index++)
        if (tracks.values[index].clips.any(
          (clip) => effectiveSelection.contains(clip.id),
        ))
          index,
    ];
    final minimumSelectedTrackIndex = selectedTrackIndices.isEmpty
        ? 0
        : selectedTrackIndices.reduce(math.min);
    final maximumSelectedTrackIndex = selectedTrackIndices.isEmpty
        ? 0
        : selectedTrackIndices.reduce(math.max);
    final orderedTrackColorValues = [
      for (final track in tracks.values) track.colorValue,
    ];

    return Listener(
      key: widget.viewportKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _beginMarquee(event, tracks, selectedClipIds),
      onPointerMove: (event) => _updateMarquee(event, tracks),
      onPointerUp: _commitMarquee,
      onPointerCancel: _cancelMarquee,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListView.builder(
            controller: widget.scrollController,
            physics: widget.scrollPhysics,
            padding: EdgeInsets.zero,
            itemCount: tracks.values.length,
            itemExtent: trackHeight,
            itemBuilder: (context, index) {
              final track = tracks.values[index];

              return TimelineTrackLane(
                key: ValueKey(track.id),
                clips: track.clips,
                trackColorValue: track.colorValue,
                gridMetrics: widget.gridMetrics,
                selectedClipIds: effectiveSelection,
                groupMinimumStartSeconds: groupMinimumStartSeconds,
                trackIndex: index,
                orderedTrackColorValues: orderedTrackColorValues,
                minimumSelectedTrackIndex: minimumSelectedTrackIndex,
                maximumSelectedTrackIndex: maximumSelectedTrackIndex,
                clipDragController: widget.clipDragController,
                bpm: bpm,
                snapSettings: snapSettings,
                onSeek: widget.onSeek,
                onSelect: (clipId, toggle, preserveExistingIfSelected) {
                  Focus.of(context).requestFocus();
                  controller.selectClip(
                    trackId: track.id,
                    clipId: clipId,
                    toggle: toggle,
                    preserveExistingIfSelected: preserveExistingIfSelected,
                  );
                },
                onMoveCommitted: (clipId, result) {
                  controller.moveClip(
                    clipId,
                    result.startSeconds,
                    trackDelta: result.trackDelta,
                  );
                },
                onTrimCommitted: (clipId, result) {
                  controller.updateClipTrim(
                    clipId: clipId,
                    timelineStartSeconds: result.startSeconds,
                    sourceStartSeconds: result.sourceStartSeconds,
                    clipDurationSeconds: result.clipDurationSeconds,
                  );
                },
                onFadeInChangeStart: controller.beginFadeInChange,
                onFadeInChanged: controller.previewFadeIn,
                onFadeInChangeEnd: controller.commitFadeInChange,
                onFadeInReset: controller.resetFadeIn,
                onFadeOutChangeStart: controller.beginFadeOutChange,
                onFadeOutChanged: controller.previewFadeOut,
                onFadeOutChangeEnd: controller.commitFadeOutChange,
                onFadeOutReset: controller.resetFadeOut,
              );
            },
          ),
          ValueListenableBuilder<TimelineClipDragState?>(
            valueListenable: widget.clipDragController,
            builder: (context, dragState, _) {
              final destinationIndex =
                  dragState?.mode == TimelineClipDragMode.move
                  ? dragState?.destinationTrackIndex
                  : null;
              if (destinationIndex == null ||
                  destinationIndex < 0 ||
                  destinationIndex >= tracks.values.length) {
                return const SizedBox.shrink();
              }
              final scrollOffset = widget.scrollController.hasClients
                  ? widget.scrollController.offset
                  : 0.0;
              final color = Theme.of(context).colorScheme.primary;
              return Positioned(
                left: 0,
                right: 0,
                top: destinationIndex * trackHeight - scrollOffset,
                height: trackHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.055),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              );
            },
          ),
          if (tracks.values.isEmpty) const _EmptyArrangementHint(),
          if (_marqueeHasDragged && _marqueeRectInViewport != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MarqueeSelectionPainter(
                    rect: _marqueeRectInViewport!,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Rect? get _marqueeRectInViewport {
    final start = _marqueeStartContent;
    final current = _marqueeCurrentContent;
    if (start == null || current == null) {
      return null;
    }
    final scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    return Rect.fromPoints(
      Offset(start.dx, start.dy - scrollOffset),
      Offset(current.dx, current.dy - scrollOffset),
    );
  }

  void _beginMarquee(
    PointerDownEvent event,
    _TimelineTracksSnapshot tracks,
    Set<String> selectedClipIds,
  ) {
    if ((event.buttons & kPrimaryMouseButton) == 0 ||
        _marqueePointer != null ||
        _hitsClip(event.localPosition, tracks)) {
      return;
    }
    Focus.of(context).requestFocus();
    final verticalOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    final contentPosition = Offset(
      event.localPosition.dx,
      event.localPosition.dy + verticalOffset,
    );
    _marqueePointer = event.pointer;
    _marqueeStartContent = contentPosition;
    _marqueeCurrentContent = contentPosition;
    _marqueeBaseSelection = {...selectedClipIds};
    _marqueeToggle = HardwareKeyboard.instance.isControlPressed;
    _marqueePreviewSelection = _marqueeToggle
        ? {...selectedClipIds}
        : <String>{};
    _marqueeHasDragged = false;
    if (!_marqueeToggle) {
      ref.read(editorControllerProvider.notifier).clearClipSelection();
    }
    setState(() {});
  }

  void _updateMarquee(PointerMoveEvent event, _TimelineTracksSnapshot tracks) {
    if (event.pointer != _marqueePointer ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final verticalOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    final current = Offset(
      event.localPosition.dx,
      event.localPosition.dy + verticalOffset,
    );
    final start = _marqueeStartContent!;
    final hasDragged =
        _marqueeHasDragged || (current - start).distance >= _marqueeThreshold;
    final marquee = Rect.fromPoints(start, current);
    final intersecting = <String>{};
    if (hasDragged) {
      for (
        var trackIndex = 0;
        trackIndex < tracks.values.length;
        trackIndex++
      ) {
        final track = tracks.values[trackIndex];
        for (final clip in track.clips) {
          if (_clipRect(clip, trackIndex).overlaps(marquee)) {
            intersecting.add(clip.id);
          }
        }
      }
    }
    final preview = _marqueeToggle
        ? _symmetricDifference(_marqueeBaseSelection, intersecting)
        : intersecting;
    setState(() {
      _marqueeCurrentContent = current;
      _marqueeHasDragged = hasDragged;
      _marqueePreviewSelection = preview;
    });
  }

  void _commitMarquee(PointerUpEvent event) {
    if (event.pointer != _marqueePointer) {
      return;
    }
    if (_marqueeHasDragged) {
      ref
          .read(editorControllerProvider.notifier)
          .setSelectedClipIds(_marqueePreviewSelection);
    }
    _resetMarquee();
  }

  void _cancelMarquee(PointerCancelEvent event) {
    if (event.pointer == _marqueePointer) {
      ref
          .read(editorControllerProvider.notifier)
          .setSelectedClipIds(_marqueeBaseSelection);
      _resetMarquee();
    }
  }

  void _resetMarquee() {
    setState(() {
      _marqueePointer = null;
      _marqueeStartContent = null;
      _marqueeCurrentContent = null;
      _marqueeBaseSelection = const {};
      _marqueePreviewSelection = const {};
      _marqueeToggle = false;
      _marqueeHasDragged = false;
    });
  }

  bool _hitsClip(Offset viewportPosition, _TimelineTracksSnapshot tracks) {
    final verticalOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    final contentPosition = Offset(
      viewportPosition.dx,
      viewportPosition.dy + verticalOffset,
    );
    final trackIndex = (contentPosition.dy / trackHeight).floor();
    if (trackIndex < 0 || trackIndex >= tracks.values.length) {
      return false;
    }
    return tracks.values[trackIndex].clips.any(
      (clip) => _clipRect(clip, trackIndex).contains(contentPosition),
    );
  }

  Rect _clipRect(AudioClip clip, int trackIndex) {
    final transform = widget.gridMetrics.transform;
    return Rect.fromLTWH(
      transform.timeToContentX(clip.timelineStartSeconds),
      trackIndex * trackHeight + 8,
      math.max(transform.timeToContentX(clip.clipDurationSeconds), 1),
      trackHeight - 16,
    );
  }

  static Set<String> _symmetricDifference(Set<String> left, Set<String> right) {
    return {
      ...left.where((id) => !right.contains(id)),
      ...right.where((id) => !left.contains(id)),
    };
  }
}

class _MarqueeSelectionPainter extends CustomPainter {
  const _MarqueeSelectionPainter({required this.rect, required this.color});

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MarqueeSelectionPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.color != color;
}

/// Ignores mixer-only track copies so fader drags do not rebuild waveforms.
class _TimelineTracksSnapshot {
  _TimelineTracksSnapshot(Iterable<DawTrack> tracks)
    : values = List<DawTrack>.unmodifiable(tracks);

  final List<DawTrack> values;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _TimelineTracksSnapshot ||
        values.length != other.values.length) {
      return false;
    }
    for (var index = 0; index < values.length; index++) {
      final left = values[index];
      final right = other.values[index];
      if (left.id != right.id ||
          left.colorValue != right.colorValue ||
          !identical(left.clips, right.clips)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
    values.map((track) => Object.hash(track.id, track.colorValue, track.clips)),
  );
}

class _EmptyArrangementHint extends StatelessWidget {
  const _EmptyArrangementHint();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.multitrack_audio, size: 30, color: Colors.white30),
            SizedBox(height: 10),
            Text(
              'Drop audio here to start',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
