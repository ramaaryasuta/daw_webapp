@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/application/snap_controller.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent revisions distinguish portable saves from later edits', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);

    expect(container.read(editorControllerProvider).hasUnsavedChanges, isFalse);
    controller.addMarker(1);
    var state = container.read(editorControllerProvider);
    expect(state.hasUnsavedChanges, isTrue);

    controller.markExplicitlySaved('Revision Test');
    state = container.read(editorControllerProvider);
    expect(state.projectName, 'Revision Test');
    expect(state.hasUnsavedChanges, isFalse);

    controller.renameMarker(state.markers.single.id, 'Changed');
    state = container.read(editorControllerProvider);
    expect(state.hasUnsavedChanges, isTrue);
    expect(
      state.projectRevision,
      greaterThan(state.lastExplicitlySavedRevision),
    );
  });

  test(
    'marker edits are snapped and recorded as atomic project history',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);

      final markerId = controller.addMarker(1.19);
      var state = container.read(editorControllerProvider);
      expect(state.markers.single.id, markerId);
      expect(state.markers.single.name, 'Marker 1');
      expect(state.markers.single.timeSeconds, 1.25);
      expect(state.history.past.last.label, 'Add Marker');

      container.read(snapControllerProvider.notifier).setEnabled(false);
      final exactMarkerId = controller.addMarker(2.137);
      state = container.read(editorControllerProvider);
      expect(
        state.markers
            .singleWhere((marker) => marker.id == exactMarkerId)
            .timeSeconds,
        2.137,
      );
      await controller.seek(2.137);
      expect(container.read(editorControllerProvider).playheadSeconds, 2.137);

      final beforeMoveHistoryLength = state.history.past.length;
      controller.beginMarkerMove(markerId);
      controller.previewMarkerMove(markerId, 3.1);
      controller.previewMarkerMove(markerId, 3.25);
      expect(
        container.read(editorControllerProvider).history.past.length,
        beforeMoveHistoryLength,
      );
      controller.commitMarkerMove(markerId);
      state = container.read(editorControllerProvider);
      expect(state.history.past.length, beforeMoveHistoryLength + 1);
      expect(state.history.past.last.label, 'Move Marker');
      expect(
        state.markers
            .singleWhere((marker) => marker.id == markerId)
            .timeSeconds,
        3.25,
      );

      controller.renameMarker(markerId, 'Chorus');
      controller.changeMarkerColor(markerId, TrackColors.red);
      expect(
        container
            .read(editorControllerProvider)
            .history
            .past
            .skip(beforeMoveHistoryLength + 1)
            .map((entry) => entry.label),
        ['Rename Marker', 'Change Marker Color'],
      );

      controller.deleteMarker(markerId);
      expect(
        container.read(editorControllerProvider).history.past.last.label,
        'Delete Marker',
      );
      expect(
        container
            .read(editorControllerProvider)
            .markers
            .any((marker) => marker.id == markerId),
        isFalse,
      );

      await controller.undo();
      final restored = container
          .read(editorControllerProvider)
          .markers
          .singleWhere((marker) => marker.id == markerId);
      expect(restored.id, markerId);
      expect(restored.timeSeconds, 3.25);
      expect(restored.name, 'Chorus');
      expect(restored.colorArgb, TrackColors.red);

      await controller.redo();
      expect(
        container
            .read(editorControllerProvider)
            .markers
            .any((marker) => marker.id == markerId),
        isFalse,
      );
    },
  );
}
