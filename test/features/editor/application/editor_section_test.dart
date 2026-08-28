@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/application/snap_controller.dart';
import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('section edits are snapped, atomic, and preserve stable IDs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);

    final sectionId = controller.addSection(1.19, 3.31);
    var state = container.read(editorControllerProvider);
    expect(sectionId, isNotEmpty);
    expect(state.sections.single.startTime, 1.25);
    expect(state.sections.single.endTime, 3.25);
    expect(state.history.past.last.label, 'Add Section');

    container.read(snapControllerProvider.notifier).setEnabled(false);
    final beforeMoveHistoryLength = state.history.past.length;
    controller.beginSectionEdit(sectionId);
    controller.previewSectionMove(sectionId, 4);
    controller.previewSectionMove(sectionId, 5);
    expect(
      container.read(editorControllerProvider).history.past.length,
      beforeMoveHistoryLength,
    );
    controller.commitSectionEdit(sectionId, isResize: false);
    state = container.read(editorControllerProvider);
    expect(state.sections.single.startTime, 5);
    expect(state.sections.single.endTime, 7);
    expect(state.history.past.last.label, 'Move Section');

    controller.beginSectionEdit(sectionId);
    controller.previewSectionStartResize(sectionId, 4.5);
    controller.previewSectionEndResize(sectionId, 8.5);
    controller.commitSectionEdit(sectionId, isResize: true);
    state = container.read(editorControllerProvider);
    expect(state.sections.single.startTime, 4.5);
    expect(state.sections.single.endTime, 8.5);
    expect(state.history.past.last.label, 'Resize Section');

    controller.renameSection(sectionId, 'Chorus');
    controller.changeSectionColor(sectionId, TrackColors.red);
    controller.deleteSection(sectionId);
    expect(
      container.read(editorControllerProvider).history.past.last.label,
      'Delete Section',
    );

    await controller.undo();
    final restored = container.read(editorControllerProvider).sections.single;
    expect(restored.id, sectionId);
    expect(restored.name, 'Chorus');
    expect(restored.colorArgb, TrackColors.red);

    await controller.redo();
    expect(container.read(editorControllerProvider).sections, isEmpty);
  });

  test('invalid zero-length section creation is cancelled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    container.read(snapControllerProvider.notifier).setEnabled(false);

    expect(controller.addSection(2, 2), isEmpty);
    expect(container.read(editorControllerProvider).sections, isEmpty);
    expect(container.read(editorControllerProvider).history.past, isEmpty);
  });
}
