import 'package:daw_webapp/features/editor/presentation/controllers/timeline_clip_drag_controller.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/domain/clip_crossfade.dart';
import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('converts pointer and scroll deltas into timeline seconds', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    var interactionCount = 0;
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () => interactionCount++,
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 300,
            height: 100,
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: const SizedBox(width: 1200, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(
      dragController.begin(
        pointer: 1,
        clipId: 'clip-1',
        pointerGlobalX: 100,
        clipStartSeconds: 5,
        clipDurationSeconds: 4,
        pixelsPerSecond: 100,
      ),
      isTrue,
    );

    dragController.update(pointer: 1, pointerGlobalX: 200);
    expect(dragController.value!.previewStartSeconds, 6);

    scrollController.jumpTo(150);
    dragController.update(pointer: 1, pointerGlobalX: 200);
    expect(dragController.value!.previewStartSeconds, 7.5);

    final result = dragController.end(1);
    expect(result!.startSeconds, 7.5);
    expect(result.didMove, isTrue);
    expect(dragController.isDragging, isFalse);
    expect(interactionCount, greaterThanOrEqualTo(3));
  });

  testWidgets('clamps a dragged clip to timeline zero', (tester) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.begin(
      pointer: 2,
      clipId: 'clip-2',
      pointerGlobalX: 200,
      clipStartSeconds: 1,
      clipDurationSeconds: 3,
      pixelsPerSecond: 100,
    );
    dragController.update(pointer: 2, pointerGlobalX: -100);

    expect(dragController.value!.previewStartSeconds, 0);
    dragController.cancel(2);
  });

  testWidgets('clamps a group drag by its earliest selected clip', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.begin(
      pointer: 9,
      clipId: 'later-anchor',
      pointerGlobalX: 200,
      clipStartSeconds: 10,
      clipDurationSeconds: 2,
      pixelsPerSecond: 100,
      minimumMoveAnchorStartSeconds: 4,
    );
    dragController.update(pointer: 9, pointerGlobalX: -1000);

    expect(dragController.value!.previewStartSeconds, 4);
    expect(dragController.value!.moveDeltaSeconds, -6);
    dragController.cancel(9);
  });

  testWidgets('uses one clamped track delta for a vertical group move', (
    tester,
  ) async {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();
    final timelineViewportKey = GlobalKey();
    final trackViewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      horizontalScrollController,
      timelineViewportKey,
      () {},
      verticalScrollController: verticalScrollController,
      trackViewportKey: trackViewportKey,
    );
    addTearDown(() {
      dragController.dispose();
      horizontalScrollController.dispose();
      verticalScrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              key: timelineViewportKey,
              width: 300,
              height: 100,
              child: SingleChildScrollView(
                controller: horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: const SizedBox(width: 1200, height: 100),
              ),
            ),
            SizedBox(
              key: trackViewportKey,
              width: 300,
              height: 220,
              child: ListView(
                controller: verticalScrollController,
                children: const [SizedBox(height: 440)],
              ),
            ),
          ],
        ),
      ),
    );

    expect(
      dragController.begin(
        pointer: 10,
        clipId: 'clip-a',
        pointerGlobalX: 100,
        pointerGlobalY: 150,
        clipStartSeconds: 5,
        clipDurationSeconds: 2,
        pixelsPerSecond: 100,
        anchorTrackIndex: 0,
        minimumSelectedTrackIndex: 0,
        maximumSelectedTrackIndex: 2,
        trackCount: 4,
      ),
      isTrue,
    );

    dragController.update(
      pointer: 10,
      pointerGlobalX: 100,
      pointerGlobalY: 290,
    );
    expect(dragController.value!.trackDelta, 1);
    expect(dragController.value!.destinationTrackIndex, 1);

    dragController.update(
      pointer: 10,
      pointerGlobalX: 100,
      pointerGlobalY: 1000,
    );
    expect(dragController.value!.trackDelta, 1);

    final result = dragController.end(10);
    expect(result!.trackDelta, 1);
    expect(result.didChange, isTrue);
    expect(result.startSeconds, 5);
  });

  testWidgets('left trim changes timeline and source starts from drag origin', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.beginTrim(
      pointer: 3,
      clipId: 'clip-3',
      mode: TimelineClipDragMode.trimStart,
      pointerGlobalX: 100,
      clipStartSeconds: 5,
      sourceStartSeconds: 0,
      clipDurationSeconds: 10,
      sourceAudioDurationSeconds: 10,
      pixelsPerSecond: 100,
    );
    dragController.update(pointer: 3, pointerGlobalX: 300);

    expect(dragController.value!.previewStartSeconds, 7);
    expect(dragController.value!.previewSourceStartSeconds, 2);
    expect(dragController.value!.clipDurationSeconds, 8);
    expect(dragController.value!.previewEndSeconds, 15);
  });

  testWidgets('trim edges restore hidden source and clamp to source bounds', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.beginTrim(
      pointer: 4,
      clipId: 'clip-4',
      mode: TimelineClipDragMode.trimStart,
      pointerGlobalX: 300,
      clipStartSeconds: 8,
      sourceStartSeconds: 3,
      clipDurationSeconds: 7,
      sourceAudioDurationSeconds: 10,
      pixelsPerSecond: 100,
    );
    dragController.update(pointer: 4, pointerGlobalX: -200);
    expect(dragController.value!.previewStartSeconds, 5);
    expect(dragController.value!.previewSourceStartSeconds, 0);
    expect(dragController.value!.clipDurationSeconds, 10);
    dragController.end(4);

    dragController.beginTrim(
      pointer: 5,
      clipId: 'clip-4',
      mode: TimelineClipDragMode.trimEnd,
      pointerGlobalX: 100,
      clipStartSeconds: 5,
      sourceStartSeconds: 2,
      clipDurationSeconds: 4,
      sourceAudioDurationSeconds: 10,
      pixelsPerSecond: 100,
    );
    dragController.update(pointer: 5, pointerGlobalX: 1000);
    expect(dragController.value!.previewStartSeconds, 5);
    expect(dragController.value!.previewSourceStartSeconds, 2);
    expect(dragController.value!.clipDurationSeconds, 8);
    dragController.end(5);
  });

  testWidgets('move snaps the timeline left edge and supports bypass', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.begin(
      pointer: 6,
      clipId: 'clip-6',
      pointerGlobalX: 100,
      clipStartSeconds: 3,
      clipDurationSeconds: 2,
      pixelsPerSecond: 100,
      bpm: 120,
      snapSettings: const SnapSettings(subdivision: SnapSubdivision.beat),
    );
    dragController.update(pointer: 6, pointerGlobalX: 131);
    expect(dragController.value!.previewStartSeconds, 3.5);

    dragController.update(pointer: 6, pointerGlobalX: 131, bypassSnap: true);
    expect(dragController.value!.previewStartSeconds, closeTo(3.31, 1e-12));
  });

  testWidgets('left and right trims snap their timeline edges', (tester) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    const settings = SnapSettings(subdivision: SnapSubdivision.beat);
    dragController.beginTrim(
      pointer: 7,
      clipId: 'clip-7',
      mode: TimelineClipDragMode.trimStart,
      pointerGlobalX: 100,
      clipStartSeconds: 2,
      sourceStartSeconds: 1,
      clipDurationSeconds: 4,
      sourceAudioDurationSeconds: 8,
      pixelsPerSecond: 100,
      bpm: 120,
      snapSettings: settings,
    );
    dragController.update(pointer: 7, pointerGlobalX: 237);
    expect(dragController.value!.previewStartSeconds, 3.5);
    expect(dragController.value!.previewSourceStartSeconds, 2.5);
    expect(dragController.value!.clipDurationSeconds, 2.5);
    expect(dragController.value!.previewEndSeconds, 6);
    dragController.end(7);

    dragController.beginTrim(
      pointer: 8,
      clipId: 'clip-8',
      mode: TimelineClipDragMode.trimEnd,
      pointerGlobalX: 100,
      clipStartSeconds: 2,
      sourceStartSeconds: 1,
      clipDurationSeconds: 4,
      sourceAudioDurationSeconds: 8,
      pixelsPerSecond: 100,
      bpm: 120,
      snapSettings: settings,
    );
    dragController.update(pointer: 8, pointerGlobalX: 137);
    expect(dragController.value!.previewStartSeconds, 2);
    expect(dragController.value!.previewSourceStartSeconds, 1);
    expect(dragController.value!.clipDurationSeconds, 4.5);
    expect(dragController.value!.previewEndSeconds, 6.5);
  });

  testWidgets('clip movement uses denominator-based 6/8 beat snapping', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 300,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );

    dragController.begin(
      pointer: 9,
      clipId: 'clip-9',
      pointerGlobalX: 100,
      clipStartSeconds: 3,
      clipDurationSeconds: 2,
      pixelsPerSecond: 100,
      bpm: 120,
      timeSignature: TimeSignature.sixEight,
      snapSettings: const SnapSettings(subdivision: SnapSubdivision.beat),
    );
    dragController.update(pointer: 9, pointerGlobalX: 131);

    expect(dragController.value!.previewStartSeconds, 3.25);
  });

  testWidgets('carries linked crossfade updates through one move result', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final viewportKey = GlobalKey();
    final dragController = TimelineClipDragController(
      scrollController,
      viewportKey,
      () {},
    );
    addTearDown(() {
      dragController.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: viewportKey,
          width: 600,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1200, height: 100),
          ),
        ),
      ),
    );
    const snapshot = CrossfadeDragSnapshot(
      trackId: 'track',
      outgoingClipId: 'a',
      incomingClipId: 'b',
      outgoingTimelineStartSeconds: 1,
      incomingTimelineStartSeconds: 4,
      outgoingClipDurationSeconds: 5,
      incomingClipDurationSeconds: 4,
      outgoingFadeInDurationSeconds: 0.5,
      incomingFadeOutDurationSeconds: 0.75,
      originalOutgoingFadeOutDurationSeconds: 2,
      originalIncomingFadeInDurationSeconds: 2,
      outgoingMoves: false,
      incomingMoves: true,
    );

    dragController.begin(
      pointer: 20,
      clipId: 'b',
      pointerGlobalX: 100,
      clipStartSeconds: 4,
      clipDurationSeconds: 4,
      pixelsPerSecond: 100,
      crossfadeSnapshots: const [snapshot],
    );
    dragController.update(pointer: 20, pointerGlobalX: 225);

    expect(
      dragController.value!.crossfadeUpdates.single.overlapDurationSeconds,
      0.75,
    );
    final result = dragController.end(20)!;
    expect(result.crossfadeSnapshots, const [snapshot]);
    expect(result.didChange, isTrue);
  });
}
