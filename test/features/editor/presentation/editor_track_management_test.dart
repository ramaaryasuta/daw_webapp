@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/presentation/editor_page.dart';
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
    expect(state.history.past.map((entry) => entry.label), [
      'Add Track',
      'Add Track',
      'Add Track',
    ]);
    expect(tester.takeException(), isNull);
  });
}
