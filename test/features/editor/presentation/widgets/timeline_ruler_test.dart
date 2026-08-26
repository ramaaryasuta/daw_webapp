import 'package:daw_webapp/features/editor/domain/loop_region.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_loop_overlay.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler_mode_control.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const metrics = TimelineGridMetrics(
    transform: TimelineTransform(scale: TimelineScale(100)),
  );

  testWidgets('defaults to Bars / Beats and preserves shared seek transform', (
    tester,
  ) async {
    double? seekSeconds;

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              onSeek: (value) => seekSeconds = value,
            ),
          ),
        ),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(TimelineRuler),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = customPaint.painter! as TimelineRulerPainter;
    expect(painter.mode, TimelineRulerMode.barsBeats);
    expect(painter.bpm, 120);

    final origin = tester.getTopLeft(find.byType(TimelineRuler));
    await tester.tapAt(origin + const Offset(150, 12));
    expect(seekSeconds, closeTo(1.5, 1e-12));
  });

  test('BPM and ruler mode changes request repaint', () {
    TimelineRulerPainter painter({
      required TimelineRulerMode mode,
      required double bpm,
    }) {
      return TimelineRulerPainter(
        color: Colors.grey,
        playheadColor: Colors.red,
        playheadSeconds: 0,
        gridMetrics: metrics,
        mode: mode,
        bpm: bpm,
        beatsPerBar: 4,
        devicePixelRatio: 1,
      );
    }

    final musical120 = painter(mode: TimelineRulerMode.barsBeats, bpm: 120);
    final musical60 = painter(mode: TimelineRulerMode.barsBeats, bpm: 60);
    final time = painter(mode: TimelineRulerMode.time, bpm: 120);

    expect(musical60.shouldRepaint(musical120), isTrue);
    expect(time.shouldRepaint(musical120), isTrue);
  });

  testWidgets('drag creates a normalized free-time loop without seeking', (
    tester,
  ) async {
    LoopRegion? loop;
    var seekCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              onSeek: (_) => seekCount++,
              onLoopRegionChanged: (value) => loop = value,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(TimelineRuler));
    await tester.dragFrom(
      origin + const Offset(480, 12),
      const Offset(-280, 0),
    );
    await tester.pump();

    expect(seekCount, 0);
    expect(loop?.startSeconds, closeTo(2, 1e-9));
    expect(loop?.endSeconds, closeTo(4.8, 1e-9));
  });

  testWidgets('loop drag reuses beat snapping at 120 BPM', (tester) async {
    LoopRegion? loop;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              snapSettings: const SnapSettings(
                subdivision: SnapSubdivision.beat,
              ),
              onSeek: (_) {},
              onLoopRegionChanged: (value) => loop = value,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(TimelineRuler));
    await tester.dragFrom(origin + const Offset(218, 12), const Offset(265, 0));
    await tester.pump();

    expect(loop?.startSeconds, closeTo(2, 1e-9));
    expect(loop?.endSeconds, closeTo(5, 1e-9));
  });

  testWidgets(
    'snapped draft drives ruler and full-height overlay before one commit',
    (tester) async {
      final draftRegion = ValueNotifier<LoopRegion?>(null);
      final verticalScrollController = ScrollController();
      addTearDown(() {
        draftRegion.dispose();
        verticalScrollController.dispose();
      });
      LoopRegion? committedRegion;
      var commitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 232,
              child: ValueListenableBuilder<LoopRegion?>(
                valueListenable: draftRegion,
                builder: (context, draft, _) {
                  final effectiveRegion = draft ?? committedRegion;
                  return Column(
                    children: [
                      TimelineRuler(
                        playheadSeconds: 0,
                        gridMetrics: metrics,
                        loopRegion: effectiveRegion,
                        snapSettings: const SnapSettings(
                          subdivision: SnapSubdivision.beat,
                        ),
                        onLoopRegionPreviewChanged: (region) {
                          draftRegion.value = region;
                        },
                        onLoopRegionChanged: (region) {
                          commitCount++;
                          committedRegion = region;
                        },
                        onSeek: (_) {},
                      ),
                      Expanded(
                        child: TimelineLoopOverlay(
                          gridMetrics: metrics,
                          playheadSeconds: 0,
                          loopRegion: effectiveRegion,
                          isLoopEnabled: true,
                          bpm: 120,
                          snapSettings: const SnapSettings(
                            subdivision: SnapSubdivision.beat,
                          ),
                          rulerMode: TimelineRulerMode.barsBeats,
                          verticalScrollController: verticalScrollController,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(TimelineRuler));
      final gesture = await tester.startGesture(
        origin + const Offset(218, 12),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveBy(const Offset(265, 0));
      await tester.pump();

      expect(commitCount, 0);
      expect(
        draftRegion.value,
        const LoopRegion(startSeconds: 2, endSeconds: 5),
      );

      final rulerPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(TimelineRuler),
          matching: find.byType(CustomPaint),
        ),
      );
      final rulerPainter = rulerPaint.painter! as TimelineRulerPainter;
      final overlayPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is TimelineLoopFillPainter,
        ),
      );
      final overlayPainter = overlayPaint.painter! as TimelineLoopFillPainter;

      expect(rulerPainter.loopRegion, draftRegion.value);
      expect(overlayPainter.loopRegion, draftRegion.value);
      expect(
        overlayPainter.loopRectForSize(const Size(600, 200)),
        const Rect.fromLTRB(200, 0, 500, 200),
      );

      await gesture.up();
      await tester.pump();

      expect(commitCount, 1);
      expect(draftRegion.value, isNull);
      expect(committedRegion, const LoopRegion(startSeconds: 2, endSeconds: 5));
    },
  );

  testWidgets('ruler selector offers Time independently of snap', (
    tester,
  ) async {
    TimelineRulerMode? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineRulerModeControl(
            mode: TimelineRulerMode.barsBeats,
            onChanged: (mode) => selectedMode = mode,
          ),
        ),
      ),
    );

    expect(find.text('Bars'), findsOneWidget);
    await tester.tap(find.byTooltip('Ruler display'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();

    expect(selectedMode, TimelineRulerMode.time);
  });
}
