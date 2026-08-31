@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/presentation/editor_page.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/track_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Mixer follows stable track order and switches without project edits',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);
      final vocalId = controller.addTrack();
      final guitarId = controller.addTrack();
      final drumsId = controller.addTrack();
      controller.renameTrack(vocalId, 'Main Vocal');
      controller.renameTrack(guitarId, 'Guitar');
      controller.renameTrack(drumsId, 'Drums');
      controller.toggleTrackEq(vocalId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const EditorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final arrangeElement = tester.element(
        find.byType(TimelineTrackList).first,
      );
      final revisionBefore = container
          .read(editorControllerProvider)
          .projectRevision;
      final historyBefore = container
          .read(editorControllerProvider)
          .history
          .past
          .length;

      await tester.tap(find.byKey(const ValueKey('workspace-mixer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mixer-workspace')), findsOneWidget);
      expect(find.byKey(ValueKey('mixer-channel-$vocalId')), findsOneWidget);
      expect(find.byKey(ValueKey('mixer-channel-$guitarId')), findsOneWidget);
      expect(find.byKey(ValueKey('mixer-channel-$drumsId')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mixer-master-channel')),
        findsOneWidget,
      );
      expect(find.text('FX 1'), findsOneWidget);
      expect(
        container.read(editorControllerProvider).projectRevision,
        revisionBefore,
      );
      expect(
        container.read(editorControllerProvider).history.past,
        hasLength(historyBefore),
      );

      final hiddenArrange = find
          .byType(TimelineTrackList, skipOffstage: false)
          .first;
      expect(tester.element(hiddenArrange), same(arrangeElement));

      controller.reorderTracks([drumsId, vocalId, guitarId]);
      await tester.pump();
      final drumsX = tester
          .getTopLeft(find.byKey(ValueKey('mixer-channel-$drumsId')))
          .dx;
      final vocalX = tester
          .getTopLeft(find.byKey(ValueKey('mixer-channel-$vocalId')))
          .dx;
      final guitarX = tester
          .getTopLeft(find.byKey(ValueKey('mixer-channel-$guitarId')))
          .dx;
      expect(drumsX, lessThan(vocalX));
      expect(vocalX, lessThan(guitarX));
    },
  );

  testWidgets('Mixer gestures use authoritative atomic controller edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    final trackId = controller.addTrack();
    controller.renameTrack(trackId, 'Bass');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const EditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-mixer')));
    await tester.pumpAndSettle();

    var historyLength = container
        .read(editorControllerProvider)
        .history
        .past
        .length;
    await tester.drag(
      find.byKey(ValueKey('mixer-fader-$trackId')),
      const Offset(0, -35),
    );
    await tester.pump();
    var state = container.read(editorControllerProvider);
    expect(state.tracks.single.volumeDb, greaterThan(0));
    expect(state.history.past, hasLength(historyLength + 1));
    expect(state.history.past.last.label, 'Change Track Volume');

    historyLength = state.history.past.length;
    await tester.drag(
      find.byKey(ValueKey('mixer-pan-$trackId')),
      const Offset(0, -20),
    );
    await tester.pump();
    state = container.read(editorControllerProvider);
    expect(state.tracks.single.pan, greaterThan(0));
    expect(state.history.past, hasLength(historyLength + 1));
    expect(state.history.past.last.label, 'Change Track Pan');

    historyLength = state.history.past.length;
    await tester.tap(find.byKey(ValueKey('mixer-mute-$trackId')));
    await tester.pump();
    state = container.read(editorControllerProvider);
    expect(state.tracks.single.isMuted, isTrue);
    expect(state.history.past, hasLength(historyLength + 1));

    await tester.tap(find.byKey(ValueKey('mixer-channel-$trackId')));
    await tester.tap(find.byKey(const ValueKey('workspace-arrange')));
    await tester.pumpAndSettle();
    expect(container.read(editorControllerProvider).selectedTrackId, trackId);
  });
}
