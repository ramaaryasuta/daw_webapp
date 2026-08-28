@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/presentation/editor_page.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/audio_level_meter.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/track_header.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/track_list.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Filter FX gestures commit once and duplicate persistent settings',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);
      final trackId = controller.addTrack();
      controller.toggleFilterFx(trackId);
      controller.toggleTrackFilterModule(trackId, highPass: true);
      final historyBeforeDrag = container
          .read(editorControllerProvider)
          .history
          .past
          .length;

      controller.beginTrackFilterChange(
        trackId,
        TrackFilterParameter.highPassFrequency,
      );
      controller.previewTrackFilterChange(
        trackId,
        TrackFilterParameter.highPassFrequency,
        160,
      );
      controller.previewTrackFilterChange(
        trackId,
        TrackFilterParameter.highPassFrequency,
        240,
      );
      expect(
        container
            .read(editorControllerProvider)
            .tracks
            .single
            .filterFx
            .highPass
            .frequencyHz,
        defaultHighPassFrequencyHz,
      );
      controller.commitTrackFilterChange(
        trackId,
        TrackFilterParameter.highPassFrequency,
        240,
      );

      var state = container.read(editorControllerProvider);
      expect(state.history.past, hasLength(historyBeforeDrag + 1));
      expect(state.history.past.last.label, 'Change HP Cutoff');
      expect(state.tracks.single.filterFx.highPass.frequencyHz, 240);

      final duplicateId = await controller.duplicateTrack(trackId);
      state = container.read(editorControllerProvider);
      final duplicate = state.tracks.singleWhere(
        (track) => track.id == duplicateId,
      );
      expect(duplicate.filterFx, state.tracks.first.filterFx);

      await controller.undo();
      await controller.undo();
      state = container.read(editorControllerProvider);
      expect(
        state.tracks.single.filterFx.highPass.frequencyHz,
        defaultHighPassFrequencyHz,
      );
    },
  );

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

  testWidgets('Track Actions opens the anchored Filter FX rack', (
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
    final trackId = container
        .read(editorControllerProvider.notifier)
        .addTrack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('track-properties-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('track-properties-fx')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('track-filter-fx-$trackId')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-filter-response')), findsOneWidget);
    expect(find.text('HIGH PASS'), findsOneWidget);
    expect(find.text('LOW PASS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter-fx-global-toggle')));
    await tester.pump();
    expect(
      container.read(editorControllerProvider).tracks.single.filterFx.enabled,
      isTrue,
    );
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

  testWidgets(
    'duplicate track inserts below with a stable ID and one undo entry',
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
      final firstId = controller.addTrack();
      final sourceId = controller.addTrack();
      final lastId = controller.addTrack();
      controller.renameTrack(sourceId, 'Vocals');
      final historyLength = container
          .read(editorControllerProvider)
          .history
          .past
          .length;
      final clipboard = container.read(editorControllerProvider).clipClipboard;

      final duplicateId = await controller.duplicateTrack(sourceId);
      await tester.pumpAndSettle();

      var state = container.read(editorControllerProvider);
      expect(duplicateId, isNotNull);
      expect(duplicateId, isNot(sourceId));
      expect(state.tracks.map((track) => track.id), [
        firstId,
        sourceId,
        duplicateId,
        lastId,
      ]);
      expect(state.tracks[2].name, 'Vocals Copy');
      expect(state.selectedTrackId, duplicateId);
      expect(state.selectedClipIds, isEmpty);
      expect(identical(state.clipClipboard, clipboard), isTrue);
      expect(state.history.past, hasLength(historyLength + 1));
      expect(state.history.past.last.label, 'Duplicate Track');

      await controller.undo();
      state = container.read(editorControllerProvider);
      expect(state.tracks.map((track) => track.id), [
        firstId,
        sourceId,
        lastId,
      ]);

      await controller.redo();
      state = container.read(editorControllerProvider);
      expect(state.tracks.map((track) => track.id), [
        firstId,
        sourceId,
        duplicateId,
        lastId,
      ]);
      expect(state.tracks[2].id, duplicateId);
      expect(state.history.past.last.label, 'Duplicate Track');
      expect(tester.takeException(), isNull);
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

  testWidgets(
    'partially visible rows stay aligned inside clipped track viewports',
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
      final trackIds = [
        for (var index = 0; index < 12; index++) controller.addTrack(),
      ];
      await tester.pumpAndSettle();

      final headerList = tester.widget<ListView>(
        find.descendant(
          of: find.byType(TrackHeaderList),
          matching: find.byType(ListView),
        ),
      );
      final timelineList = tester.widget<ListView>(
        find.descendant(
          of: find.byType(TimelineTrackList),
          matching: find.byType(ListView),
        ),
      );
      final headerScrollController = headerList.controller!;
      final timelineScrollController = timelineList.controller!;
      expect(
        find.byKey(const ValueKey('track-header-scrollbar-suppression')),
        findsOneWidget,
      );

      headerScrollController.jumpTo(5 * trackHeight + trackHeight / 2);
      await tester.pump();

      expect(
        timelineScrollController.offset,
        closeTo(headerScrollController.offset, 0.001),
      );

      final headerClipFinder = find.byKey(
        const ValueKey('track-header-viewport-clip'),
      );
      final timelineClipFinder = find.byKey(
        const ValueKey('timeline-track-viewport-clip'),
      );
      final headerClip = tester.widget<ClipRect>(headerClipFinder);
      final timelineClip = tester.widget<ClipRect>(timelineClipFinder);
      expect(headerClip.clipBehavior, Clip.hardEdge);
      expect(timelineClip.clipBehavior, Clip.hardEdge);

      final rulerRect = tester.getRect(find.byType(TimelineRuler));
      final headerViewportRect = tester.getRect(headerClipFinder);
      final timelineViewportRect = tester.getRect(timelineClipFinder);
      expect(headerViewportRect.top, closeTo(rulerRect.bottom, 0.001));
      expect(timelineViewportRect.top, closeTo(rulerRect.bottom, 0.001));
      expect(
        headerViewportRect.height,
        closeTo(timelineViewportRect.height, 0.001),
      );

      final partiallyVisibleHeader = find.descendant(
        of: find.byType(TrackHeaderList),
        matching: find.byKey(ValueKey(trackIds[5])),
      );
      final partiallyVisibleLane = find.descendant(
        of: find.byType(TimelineTrackList),
        matching: find.byKey(ValueKey(trackIds[5])),
      );
      expect(
        tester.getTopLeft(partiallyVisibleHeader).dy,
        closeTo(headerViewportRect.top - trackHeight / 2, 0.001),
      );
      expect(
        tester.getTopLeft(partiallyVisibleLane).dy,
        closeTo(timelineViewportRect.top - trackHeight / 2, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
