import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/clip_crossfade.dart';
import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/presentation/controllers/timeline_clip_drag_controller.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dragging a clip edge trims instead of moving or seeking', (
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
    TimelineClipDragResult? trimResult;
    var moveCommitCount = 0;
    var seekCount = 0;
    var selectCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 600,
            height: 100,
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1000,
                child: TimelineTrackLane(
                  clips: const [
                    AudioClip(
                      id: 'clip-1',
                      audio: AudioAsset(
                        id: 'asset-1',
                        name: 'clip.wav',
                        extension: 'wav',
                        size: 1024,
                        durationSeconds: 10,
                        sampleRate: 48000,
                        numberOfChannels: 2,
                        waveformPeaks: [0.2, 0.8, 0.4, 1],
                      ),
                      timelineStartSeconds: 1,
                      clipDurationSeconds: 4,
                      gainDb: -6,
                      fadeInDurationSeconds: 0.5,
                      fadeOutDurationSeconds: 0.75,
                    ),
                  ],
                  gridMetrics: const TimelineGridMetrics(
                    transform: TimelineTransform(scale: TimelineScale(100)),
                  ),
                  selectedClipIds: const {'clip-1'},
                  groupMinimumStartSeconds: 1,
                  trackIndex: 0,
                  orderedTrackColorValues: const [0xFF8468C8],
                  minimumSelectedTrackIndex: 0,
                  maximumSelectedTrackIndex: 0,
                  clipDragController: dragController,
                  onSeek: (_) => seekCount++,
                  onSelect: (_, _, _) => selectCount++,
                  onMoveCommitted: (_, _) => moveCommitCount++,
                  onTrimCommitted: (_, result) => trimResult = result,
                  onGainChangeStart: (_) {},
                  onGainChanged: (_, _) {},
                  onGainChangeEnd: (_) {},
                  onGainReset: (_) {},
                  onFadeInChangeStart: (_) {},
                  onFadeInChanged: (_, _) {},
                  onFadeInChangeEnd: (_) {},
                  onFadeInReset: (_) {},
                  onFadeOutChangeStart: (_) {},
                  onFadeOutChanged: (_, _) {},
                  onFadeOutChangeEnd: (_) {},
                  onFadeOutReset: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final laneOrigin = tester.getTopLeft(find.byType(TimelineTrackLane));
    final contextGesture = await tester.startGesture(
      laneOrigin + const Offset(250, 40),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await contextGesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Clip Properties'), findsNothing);
    expect(selectCount, 0);
    expect(seekCount, 0);

    await tester.tapAt(laneOrigin + const Offset(250, 40));
    await tester.pump(kDoubleTapTimeout);
    expect(selectCount, 1);
    expect(find.text('Clip Properties'), findsNothing);
    expect(moveCommitCount, 0);
    expect(trimResult, isNull);
    expect(seekCount, 0);

    await tester.tapAt(laneOrigin + const Offset(250, 40));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(laneOrigin + const Offset(250, 40));
    await tester.pumpAndSettle();
    expect(find.text('Clip Properties'), findsOneWidget);
    expect(find.byKey(const ValueKey('clip-gain-slider')), findsOneWidget);
    expect(find.text('-6.0 dB'), findsWidgets);
    expect(find.byKey(const ValueKey('clip-fade-in-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('clip-fade-out-slider')), findsOneWidget);
    expect(selectCount, greaterThan(1));
    expect(seekCount, 0);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      laneOrigin + const Offset(101, 40),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveBy(const Offset(100, 0));
    await gesture.up();
    await tester.pump();

    expect(trimResult, isNotNull);
    expect(trimResult!.mode, TimelineClipDragMode.trimStart);
    expect(trimResult!.startSeconds, closeTo(2, 0.000001));
    expect(trimResult!.sourceStartSeconds, closeTo(1, 0.000001));
    expect(trimResult!.clipDurationSeconds, closeTo(3, 0.000001));
    expect(moveCommitCount, 0);
    expect(seekCount, 0);

    final moveGesture = await tester.startGesture(
      laneOrigin + const Offset(250, 40),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await moveGesture.moveBy(const Offset(30, 0));
    await moveGesture.up();
    await tester.pump(kDoubleTapTimeout);
    expect(moveCommitCount, 1);
    expect(seekCount, 0);
  });

  testWidgets('selected overlap exposes create and active crossfade visuals', (
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
    var createCount = 0;
    var removeCount = 0;

    Future<void> pumpLane({required bool active}) {
      const asset = AudioAsset(
        id: 'asset-xfade',
        name: 'clip.wav',
        extension: 'wav',
        size: 1024,
        durationSeconds: 10,
        sampleRate: 48000,
        numberOfChannels: 2,
        waveformPeaks: [0.2, 0.8, 0.4, 1],
      );
      return tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: viewportKey,
              width: 800,
              height: 100,
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1200,
                  height: 100,
                  child: TimelineTrackLane(
                    clips: [
                      AudioClip(
                        id: 'clip-a',
                        audio: asset,
                        timelineStartSeconds: 1,
                        clipDurationSeconds: 5,
                        fadeInDurationSeconds: 0.5,
                        fadeOutDurationSeconds: active ? 2 : 0.25,
                      ),
                      AudioClip(
                        id: 'clip-b',
                        audio: asset,
                        timelineStartSeconds: 4,
                        clipDurationSeconds: 4,
                        fadeInDurationSeconds: active ? 2 : 0.25,
                        fadeOutDurationSeconds: 0.5,
                      ),
                    ],
                    gridMetrics: const TimelineGridMetrics(
                      transform: TimelineTransform(scale: TimelineScale(100)),
                    ),
                    selectedClipIds: const {'clip-a', 'clip-b'},
                    groupMinimumStartSeconds: 1,
                    trackIndex: 0,
                    orderedTrackColorValues: const [0xFF8468C8],
                    minimumSelectedTrackIndex: 0,
                    maximumSelectedTrackIndex: 0,
                    clipDragController: dragController,
                    onSeek: (_) {},
                    onSelect: (_, _, _) {},
                    onMoveCommitted: (_, _) {},
                    onTrimCommitted: (_, _) {},
                    onGainChangeStart: (_) {},
                    onGainChanged: (_, _) {},
                    onGainChangeEnd: (_) {},
                    onGainReset: (_) {},
                    onFadeInChangeStart: (_) {},
                    onFadeInChanged: (_, _) {},
                    onFadeInChangeEnd: (_) {},
                    onFadeInReset: (_) {},
                    onFadeOutChangeStart: (_) {},
                    onFadeOutChanged: (_, _) {},
                    onFadeOutChangeEnd: (_) {},
                    onFadeOutReset: (_) {},
                    onCreateCrossfade: () => createCount++,
                    onRemoveCrossfade: () => removeCount++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpLane(active: false);
    expect(find.byKey(const ValueKey('create-crossfade-button')), findsOne);
    expect(find.text('XFADE'), findsOne);
    expect(
      find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('create-crossfade-button')));
    expect(createCount, 1);

    await pumpLane(active: true);
    expect(
      find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('remove-crossfade-button')), findsOne);
    expect(find.text('REMOVE XFADE'), findsOne);

    const snapshot = CrossfadeDragSnapshot(
      trackId: 'timeline-lane',
      outgoingClipId: 'clip-a',
      incomingClipId: 'clip-b',
      outgoingTimelineStartSeconds: 1,
      incomingTimelineStartSeconds: 4,
      outgoingClipDurationSeconds: 5,
      incomingClipDurationSeconds: 4,
      outgoingFadeInDurationSeconds: 0.5,
      incomingFadeOutDurationSeconds: 0.5,
      originalOutgoingFadeOutDurationSeconds: 2,
      originalIncomingFadeInDurationSeconds: 2,
      outgoingMoves: false,
      incomingMoves: true,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')))
          .width,
      200,
    );
    dragController.begin(
      pointer: 30,
      clipId: 'clip-b',
      pointerGlobalX: 500,
      clipStartSeconds: 4,
      clipDurationSeconds: 4,
      pixelsPerSecond: 100,
      crossfadeSnapshots: const [snapshot],
    );
    dragController.update(pointer: 30, pointerGlobalX: 625);
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')))
          .width,
      75,
    );
    expect(find.byKey(const ValueKey('remove-crossfade-button')), findsNothing);

    dragController.update(pointer: 30, pointerGlobalX: 700);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')),
      findsNothing,
    );
    dragController.cancel(30);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('crossfade-region-clip-a-clip-b')),
      findsOne,
    );
    await tester.tap(find.byKey(const ValueKey('remove-crossfade-button')));
    expect(removeCount, 1);
  });
}
