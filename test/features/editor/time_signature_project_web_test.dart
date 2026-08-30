@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/application/tempo_controller.dart';
import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/flaudio_project_codec.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/project_autosave_store.dart';
import 'package:daw_webapp/features/editor/presentation/models/timeline_ruler_mode.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/time_signature_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection is one undoable project edit', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: TimeSignatureControl())),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('time-signature-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-signature-3/4')));
    await tester.pumpAndSettle();

    expect(
      container.read(tempoControllerProvider).timeSignature,
      TimeSignature.threeFour,
    );
    expect(container.read(editorControllerProvider).projectRevision, 1);
    expect(
      container.read(editorControllerProvider).history.undoLabel,
      'Change Time Signature',
    );

    await container.read(editorControllerProvider.notifier).undo();
    expect(
      container.read(tempoControllerProvider).timeSignature,
      TimeSignature.commonTime,
    );
    await container.read(editorControllerProvider.notifier).redo();
    expect(
      container.read(tempoControllerProvider).timeSignature,
      TimeSignature.threeFour,
    );
  });

  test('IndexedDB autosave round-trips project time signature', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(projectAutosaveStoreProvider);
    addTearDown(store.discardRecovery);
    await store.discardRecovery();

    final document = const FlaudioProjectCodec().encodeSnapshot(
      const FlaudioProjectSnapshot(
        name: 'Meter Recovery',
        bpm: 120,
        timeSignature: TimeSignature.sixEight,
        snapSettings: SnapSettings(),
        rulerMode: TimelineRulerMode.barsBeats,
        isLoopEnabled: false,
        loopRegion: null,
        masterVolumeDb: 0,
        tracks: [],
        markers: [],
      ),
    );

    await store.saveDocument(document);
    final recovery = await store.readRecovery();
    expect(recovery, isNotNull);
    final restoredDocument = await store.loadDocument(recovery!);
    expect(
      restoredDocument.manifest.project.timeSignature,
      TimeSignature.sixEight,
    );
  });
}
