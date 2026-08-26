import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/presentation/controllers/timeline_clip_drag_controller.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
                    ),
                  ],
                  gridMetrics: const TimelineGridMetrics(
                    transform: TimelineTransform(scale: TimelineScale(100)),
                  ),
                  selectedClipId: null,
                  clipDragController: dragController,
                  onSeek: (_) => seekCount++,
                  onSelect: (_) {},
                  onMoveCommitted: (_, _) => moveCommitCount++,
                  onTrimCommitted: (_, result) => trimResult = result,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final laneOrigin = tester.getTopLeft(find.byType(TimelineTrackLane));
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
  });
}
