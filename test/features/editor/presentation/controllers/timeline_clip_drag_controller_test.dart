import 'package:daw_webapp/features/editor/presentation/controllers/timeline_clip_drag_controller.dart';
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
}
