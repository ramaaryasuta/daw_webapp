@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/presentation/editor_page.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/audio_level_meter.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/track_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tracks add button creates real tracks with stable defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

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

    final addButton = find.byKey(const ValueKey('add-audio-track-button'));
    expect(addButton, findsOneWidget);
    expect(find.byType(MasterStereoMeter), findsOneWidget);
    expect(find.byType(TrackStereoMeter), findsNothing);
    expect(find.byTooltip('Add audio track'), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      await tester.tap(addButton);
      await tester.pumpAndSettle();
    }

    final state = container.read(editorControllerProvider);
    expect(state.tracks.map((track) => track.id).toSet().length, 3);
    expect(state.tracks.map((track) => track.name), [
      'Track 1',
      'Track 2',
      'Track 3',
    ]);
    expect(state.tracks.map((track) => track.colorValue), [
      TrackColors.purple,
      TrackColors.blue,
      TrackColors.cyan,
    ]);
    expect(state.tracks.every((track) => track.clips.isEmpty), isTrue);
    expect(state.tracks.every((track) => track.volumeDb == 0), isTrue);
    expect(state.tracks.every((track) => track.pan == 0), isTrue);
    expect(
      state.tracks.every((track) => !track.isMuted && !track.isSolo),
      isTrue,
    );
    expect(find.byType(TrackStereoMeter), findsNWidgets(3));
    expect(state.history.past.map((entry) => entry.label), [
      'Add Track',
      'Add Track',
      'Add Track',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'track handle previews and commits one stable-ID reorder with undo and redo',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);

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

      final controller = container.read(editorControllerProvider.notifier);
      final ids = [
        controller.addTrack(),
        controller.addTrack(),
        controller.addTrack(),
      ];
      await tester.pumpAndSettle();

      expect(find.byTooltip('Drag to reorder track'), findsNWidgets(3));
      final thirdHandle = find.byKey(
        ValueKey('track-reorder-handle-${ids[2]}'),
      );
      final gesture = await tester.startGesture(tester.getCenter(thirdHandle));
      await gesture.moveBy(const Offset(0, -2 * trackHeight));
      await tester.pump();

      // Pointer movement only changes the synchronized visual preview.
      expect(
        container.read(editorControllerProvider).tracks.map((t) => t.id),
        ids,
      );
      expect(
        find.byKey(const ValueKey('track-reorder-header-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('track-reorder-timeline-overlay')),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(editorControllerProvider).tracks.map((t) => t.id), [
        ids[2],
        ids[0],
        ids[1],
      ]);
      expect(
        container.read(editorControllerProvider).history.past.last.label,
        'Reorder Tracks',
      );
      expect(
        container
            .read(editorControllerProvider)
            .history
            .past
            .where((entry) => entry.label == 'Reorder Tracks'),
        hasLength(1),
      );

      await controller.undo();
      await tester.pump();
      expect(
        container.read(editorControllerProvider).tracks.map((t) => t.id),
        ids,
      );

      await controller.redo();
      await tester.pump();
      expect(container.read(editorControllerProvider).tracks.map((t) => t.id), [
        ids[2],
        ids[0],
        ids[1],
      ]);
    },
  );

  testWidgets('dropping a track handle in its current row is a history no-op', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

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

    final controller = container.read(editorControllerProvider.notifier);
    final trackId = controller.addTrack();
    await tester.pumpAndSettle();
    final historyLength = container
        .read(editorControllerProvider)
        .history
        .past
        .length;
    final handle = find.byKey(ValueKey('track-reorder-handle-$trackId'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 8));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      container.read(editorControllerProvider).history.past,
      hasLength(historyLength),
    );
    expect(container.read(editorControllerProvider).tracks.single.id, trackId);
  });
}
