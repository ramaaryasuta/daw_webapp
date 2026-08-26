import 'package:daw_webapp/features/editor/domain/loop_region.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/musical_grid_painter.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_loop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const metrics = TimelineGridMetrics(
    transform: TimelineTransform(scale: TimelineScale(100)),
  );
  const loop = LoopRegion(startSeconds: 1, endSeconds: 3);

  testWidgets('uses one shared overlay and never intercepts row input', (
    tester,
  ) async {
    var tapCount = 0;
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 240,
            child: TimelineLoopOverlay(
              gridMetrics: metrics,
              playheadSeconds: 2,
              loopRegion: loop,
              isLoopEnabled: true,
              bpm: 120,
              snapSettings: const SnapSettings(enabled: false),
              rulerMode: TimelineRulerMode.barsBeats,
              verticalScrollController: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: 12,
                itemExtent: 48,
                itemBuilder: (context, index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapCount++,
                  child: Text('Track ${index + 1}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TimelineLoopOverlay), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is MusicalGridPainter,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is TimelineLoopFillPainter,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is TimelineLoopLinesPainter,
      ),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(150, 24));
    await tester.pump();
    expect(tapCount, 1);

    scrollController.jumpTo(240);
    await tester.pump();
    expect(scrollController.offset, 240);
    expect(find.text('Track 7'), findsOneWidget);
    expect(find.byType(TimelineLoopOverlay), findsOneWidget);
  });

  test('fill uses exact timeline geometry and enabled emphasis', () {
    const disabled = TimelineLoopFillPainter(
      color: Colors.red,
      gridMetrics: metrics,
      loopRegion: loop,
      isLoopEnabled: false,
    );
    const enabled = TimelineLoopFillPainter(
      color: Colors.red,
      gridMetrics: metrics,
      loopRegion: loop,
      isLoopEnabled: true,
    );

    expect(
      enabled.loopRectForSize(const Size(400, 80)),
      const Rect.fromLTRB(100, 0, 300, 80),
    );
    expect(enabled.fillColor.a, greaterThan(disabled.fillColor.a));
  });

  test('painters repaint only for relevant visual geometry and state', () {
    const fill = TimelineLoopFillPainter(
      color: Colors.red,
      gridMetrics: metrics,
      loopRegion: loop,
      isLoopEnabled: false,
    );
    const lines = TimelineLoopLinesPainter(
      loopColor: Colors.red,
      playheadColor: Colors.green,
      gridMetrics: metrics,
      loopRegion: loop,
      isLoopEnabled: false,
      playheadSeconds: 2,
      devicePixelRatio: 1,
    );

    expect(fill.shouldRepaint(fill), isFalse);
    expect(lines.shouldRepaint(lines), isFalse);
    expect(
      fill.shouldRepaint(
        const TimelineLoopFillPainter(
          color: Colors.red,
          gridMetrics: metrics,
          loopRegion: loop,
          isLoopEnabled: true,
        ),
      ),
      isTrue,
    );
    expect(
      lines.shouldRepaint(
        const TimelineLoopLinesPainter(
          loopColor: Colors.red,
          playheadColor: Colors.green,
          gridMetrics: metrics,
          loopRegion: loop,
          isLoopEnabled: false,
          playheadSeconds: 2.5,
          devicePixelRatio: 1,
        ),
      ),
      isTrue,
    );
  });

  test(
    'musical grid hides dense visual detail without changing snap state',
    () {
      MusicalGridPainter painter(double pixelsPerSecond) => MusicalGridPainter(
        color: Colors.grey,
        gridMetrics: TimelineGridMetrics(
          transform: TimelineTransform(scale: TimelineScale(pixelsPerSecond)),
        ),
        bpm: 120,
        settings: const SnapSettings(subdivision: SnapSubdivision.quarterBeat),
        devicePixelRatio: 1,
      );

      final zoomedOut = painter(2);
      final zoomedIn = painter(400);

      expect(zoomedOut.paintsBeatLines, isFalse);
      expect(zoomedOut.paintsSubdivisionLines, isFalse);
      expect(zoomedIn.paintsBeatLines, isTrue);
      expect(zoomedIn.paintsSubdivisionLines, isTrue);
      expect(zoomedOut.settings.subdivision, SnapSubdivision.quarterBeat);
    },
  );
}
