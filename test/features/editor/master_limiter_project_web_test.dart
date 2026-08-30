@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/domain/master_limiter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggle and one parameter drag are atomic undoable edits', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);

    controller.toggleMasterLimiter();
    expect(
      container.read(editorControllerProvider).masterLimiter.enabled,
      isTrue,
    );
    expect(
      container.read(editorControllerProvider).history.undoLabel,
      'Toggle Master Limiter',
    );

    final historyLength = container
        .read(editorControllerProvider)
        .history
        .past
        .length;
    controller.beginMasterLimiterChange(MasterLimiterParameter.threshold);
    controller.previewMasterLimiterChange(MasterLimiterParameter.threshold, -7);
    controller.previewMasterLimiterChange(MasterLimiterParameter.threshold, -8);
    controller.commitMasterLimiterChange(MasterLimiterParameter.threshold, -8);

    var state = container.read(editorControllerProvider);
    expect(state.masterLimiter.thresholdDb, -8);
    expect(state.history.past, hasLength(historyLength + 1));
    expect(state.history.undoLabel, 'Change Limiter Threshold');

    await controller.undo();
    state = container.read(editorControllerProvider);
    expect(state.masterLimiter.thresholdDb, defaultMasterLimiterThresholdDb);
    expect(state.masterLimiter.enabled, isTrue);

    await controller.redo();
    expect(
      container.read(editorControllerProvider).masterLimiter.thresholdDb,
      -8,
    );
  });

  test('reset preserves bypass state and records one undo entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);

    controller.beginMasterLimiterChange(MasterLimiterParameter.release);
    controller.commitMasterLimiterChange(MasterLimiterParameter.release, .7);
    final beforeReset = container
        .read(editorControllerProvider)
        .history
        .past
        .length;
    controller.resetMasterLimiter();

    final state = container.read(editorControllerProvider);
    expect(state.masterLimiter, const MasterLimiterSettings());
    expect(state.history.past, hasLength(beforeReset + 1));
    expect(state.history.undoLabel, 'Reset Master Limiter');
  });
}
