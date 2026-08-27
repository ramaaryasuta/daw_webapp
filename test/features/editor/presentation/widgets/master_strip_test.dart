import 'package:daw_webapp/features/editor/domain/audio_meter.dart';
import 'package:daw_webapp/features/editor/presentation/controllers/audio_meter_controller.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/master_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AudioMeterController meterController;

  setUp(() {
    meterController = AudioMeterController(_SilentPeakSource());
  });

  tearDown(() {
    meterController.dispose();
  });

  testWidgets('vertical drag previews live and commits once', (tester) async {
    var starts = 0;
    var ends = 0;
    final previews = <double>[];

    await tester.pumpWidget(
      _Harness(
        width: 236,
        child: MasterStrip(
          volumeDb: 0,
          meterController: meterController,
          onChangeStart: () => starts++,
          onChanged: previews.add,
          onChangeEnd: (_) => ends++,
          onReset: () {},
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('master-volume-knob')),
      const Offset(0, 30),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(starts, 1);
    expect(ends, 1);
    expect(previews, isNotEmpty);
    expect(previews.last, lessThan(0));
    final value = tester.widget<Text>(
      find.byKey(const ValueKey('master-volume-value')),
    );
    expect(value.data, isNot('0.0 dB'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('double-click resets and narrow layout does not overflow', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      _Harness(
        width: 180,
        child: MasterStrip(
          volumeDb: -12,
          meterController: meterController,
          onChangeStart: () {},
          onChanged: (_) {},
          onChangeEnd: (_) {},
          onReset: () => resets++,
        ),
      ),
    );

    final knob = find.byKey(const ValueKey('master-volume-knob'));
    await tester.tap(knob);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(knob);
    await tester.pump(const Duration(milliseconds: 350));

    expect(resets, 1);
    expect(find.text('0.0 dB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: 64, child: child),
        ),
      ),
    );
  }
}

class _SilentPeakSource implements AudioMeterPeakSource {
  @override
  MeterPeaksSnapshot readMeterPeaks() =>
      const MeterPeaksSnapshot(tracks: {}, master: StereoPeak.silence);
}
