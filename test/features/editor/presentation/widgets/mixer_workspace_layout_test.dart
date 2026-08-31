@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/audio_meter.dart';
import 'package:daw_webapp/features/editor/presentation/controllers/audio_meter_controller.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/mixer_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('24 mixer channels stay fixed-width with a pinned Master strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    final meterController = AudioMeterController(_SilentPeakSource());
    addTearDown(container.dispose);
    addTearDown(meterController.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    final trackIds = [
      for (var index = 0; index < 24; index++) controller.addTrack(),
    ];
    controller.renameTrack(trackIds.first, 'Backing Vocals Wide and Layered');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: MixerWorkspace(
              meterController: meterController,
              onBackToArrange: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('mixer-master-channel')), findsOneWidget);
    expect(
      find.byKey(ValueKey('mixer-channel-${trackIds.first}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('mixer-channel-${trackIds.last}')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(ValueKey('mixer-channel-${trackIds.first}')))
          .width,
      108,
    );
    expect(
      tester.getTopRight(find.byKey(const ValueKey('mixer-master-channel'))).dx,
      lessThanOrEqualTo(1024),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short mixer height uses compact strips without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    final meterController = AudioMeterController(_SilentPeakSource());
    addTearDown(container.dispose);
    addTearDown(meterController.dispose);
    final trackId = container
        .read(editorControllerProvider.notifier)
        .addTrack();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: MixerWorkspace(
              meterController: meterController,
              onBackToArrange: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(ValueKey('mixer-channel-$trackId'))).width,
      102,
    );
    expect(find.byKey(ValueKey('mixer-pan-$trackId')), findsOneWidget);
    expect(find.byKey(ValueKey('mixer-mute-$trackId')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SilentPeakSource implements AudioMeterPeakSource {
  @override
  MeterPeaksSnapshot readMeterPeaks() =>
      const MeterPeaksSnapshot(tracks: {}, master: StereoPeak.silence);
}
