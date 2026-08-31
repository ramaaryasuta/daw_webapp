import 'package:daw_webapp/features/editor/domain/track_mixer.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/mixer_vertical_fader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one vertical fader drag has one begin and one commit', (
    tester,
  ) async {
    var value = 0.0;
    var starts = 0;
    var commits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 72,
              height: 260,
              child: MixerVerticalFader(
                valueDb: value,
                minimumDb: minimumTrackVolumeDb,
                maximumDb: maximumTrackVolumeDb,
                unityDb: unityTrackVolumeDb,
                semanticLabel: 'Vocal volume',
                valueFormatter: formatTrackVolumeDb,
                onChangeStart: () => starts++,
                onChanged: (next) => value = next,
                onChangeEnd: (next) {
                  value = next;
                  commits++;
                },
                onReset: () => value = unityTrackVolumeDb,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(MixerVerticalFader), const Offset(0, -70));
    await tester.pump(const Duration(milliseconds: 400));

    expect(starts, 1);
    expect(commits, 1);
    expect(value, greaterThan(0));
    expect(value, lessThanOrEqualTo(maximumTrackVolumeDb));
  });

  testWidgets('double-click resets the fader to unity', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 72,
              height: 260,
              child: MixerVerticalFader(
                valueDb: -18,
                minimumDb: minimumTrackVolumeDb,
                maximumDb: maximumTrackVolumeDb,
                unityDb: unityTrackVolumeDb,
                semanticLabel: 'Vocal volume',
                valueFormatter: formatTrackVolumeDb,
                onChangeStart: () {},
                onChanged: (_) {},
                onChangeEnd: (_) {},
                onReset: () => resetCount++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MixerVerticalFader));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(MixerVerticalFader));
    await tester.pumpAndSettle();

    expect(resetCount, 1);
  });
}
