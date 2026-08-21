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
                  clipId: 'clip-1',
                  fileName: 'clip.wav',
                  clipDurationSeconds: 4,
                  sourceStartSeconds: 0,
                  sourceAudioDurationSeconds: 10,
                  startTimeSeconds: 1,
                  waveformPeaks: const [0.2, 0.8, 0.4, 1],
                  playheadSeconds: 0,
                  gridMetrics: const TimelineGridMetrics(
                    transform: TimelineTransform(
                      scale: TimelineScale(100),
                    ),
                  ),
                  isSelected: false,
                  clipDragController: dragController,
                  onSeek: (_) => seekCount++,
                  onSelect: () {},
                  onMoveCommitted: (_) => moveCommitCount++,
                  onTrimCommitted: (result) => trimResult = result,
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
