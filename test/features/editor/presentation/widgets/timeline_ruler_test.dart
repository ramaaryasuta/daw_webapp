import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler_mode_control.dart';
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
