import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:daw_webapp/features/editor/presentation/editor_shortcut_policy.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/track_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required ValueChanged<String> onRename,
    VoidCallback? onColorEditStarted,
    ValueChanged<int>? onColorPreviewed,
    VoidCallback? onColorEditCommitted,
    VoidCallback? onColorEditCancelled,
    String name = 'Track 1',
    int colorValue = TrackColors.purple,
    double volumeDb = 0,
    double pan = 0,
    bool isMuted = false,
    bool isSolo = false,
    VoidCallback? onMutePressed,
    VoidCallback? onSoloPressed,
    VoidCallback? onDuplicatePressed,
    VoidCallback? onDeletePressed,
    VoidCallback? onVolumeReset,
    VoidCallback? onPanReset,
    VoidCallback? onReorderStarted,
    ValueChanged<DragUpdateDetails>? onReorderUpdated,
    VoidCallback? onReorderEnded,
    Widget? trackFxRack,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TrackHeader(
              name: name,
              colorValue: colorValue,
              volumeDb: volumeDb,
              pan: pan,
              isMuted: isMuted,
              isSolo: isSolo,
              isSelected: false,
              onTap: () {},
              onRename: onRename,
              onColorEditStarted: onColorEditStarted ?? () {},
              onColorPreviewed: onColorPreviewed ?? (_) {},
              onColorEditCommitted: onColorEditCommitted ?? () {},
              onColorEditCancelled: onColorEditCancelled ?? () {},
              onColorSelected: (_) {},
              onMutePressed: onMutePressed ?? () {},
              onSoloPressed: onSoloPressed ?? () {},
              onDuplicatePressed: onDuplicatePressed ?? () {},
              onDeletePressed: onDeletePressed ?? () {},
              onVolumeChangeStart: (_) {},
              onVolumeChanged: (_) {},
              onVolumeChangeEnd: (_) {},
              onVolumeReset: onVolumeReset ?? () {},
              onPanChangeStart: (_) {},
              onPanChanged: (_) {},
              onPanChangeEnd: (_) {},
              onPanReset: onPanReset ?? () {},
              onReorderStarted: onReorderStarted ?? () {},
              onReorderUpdated: onReorderUpdated ?? (_) {},
              onReorderEnded: onReorderEnded ?? () {},
              trackFxRack: trackFxRack,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> beginRename(WidgetTester tester) async {
    final label = find.byKey(const ValueKey('track-name-label'));
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'double-click rename selects text and Enter commits trimmed name',
    (tester) async {
      String? renamedTo;
      await pumpHeader(tester, onRename: (name) => renamedTo = name);

      await beginRename(tester);

      final field = find.byKey(const ValueKey('track-name-editor'));
      expect(field, findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(
        editable.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      expect(EditorShortcutPolicy.primaryFocusIsEditable, isTrue);

      await tester.enterText(field, '  Lead Vocal  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(renamedTo, 'Lead Vocal');
      expect(find.byKey(const ValueKey('track-name-editor')), findsNothing);
    },
  );

  testWidgets('Escape cancels rename and empty commit keeps the old name', (
    tester,
  ) async {
    final renames = <String>[];
    await pumpHeader(tester, onRename: renames.add);

    await beginRename(tester);
    await tester.enterText(
      find.byKey(const ValueKey('track-name-editor')),
      'Discard me',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(renames, isEmpty);

    await beginRename(tester);
    await tester.enterText(
      find.byKey(const ValueKey('track-name-editor')),
      'Track 1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(renames, isEmpty);
    expect(find.text('Track 1'), findsOneWidget);

    await beginRename(tester);
    await tester.enterText(
      find.byKey(const ValueKey('track-name-editor')),
      '   ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(renames, isEmpty);
  });

  testWidgets(
    'anchored preset picker commits one color without layout errors',
    (tester) async {
      var started = 0;
      var committed = 0;
      var cancelled = 0;
      final previews = <int>[];
      await pumpHeader(
        tester,
        onRename: (_) {},
        onColorEditStarted: () => started++,
        onColorPreviewed: previews.add,
        onColorEditCommitted: () => committed++,
        onColorEditCancelled: () => cancelled++,
      );

      await tester.tap(find.byKey(const ValueKey('track-color-swatch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('track-color-popover')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('track-color-preset-blue')));
      await tester.pumpAndSettle();
      expect(previews, [TrackColors.blue]);
      expect(started, 1);
      expect(committed, 1);
      expect(cancelled, 0);
      expect(find.byKey(const ValueKey('track-color-popover')), findsNothing);
    },
  );

  testWidgets('custom hex previews and Done commits while Escape cancels', (
    tester,
  ) async {
    var committed = 0;
    var cancelled = 0;
    final previews = <int>[];
    await pumpHeader(
      tester,
      onRename: (_) {},
      onColorPreviewed: previews.add,
      onColorEditCommitted: () => committed++,
      onColorEditCancelled: () => cancelled++,
    );

    await tester.tap(find.byKey(const ValueKey('track-color-swatch')));
    await tester.pumpAndSettle();
    final hexField = find.byKey(const ValueKey('track-color-hex-field'));
    await tester.enterText(hexField, '#123456');
    await tester.pump();
    expect(previews.last, 0xFF123456);
    expect(EditorShortcutPolicy.primaryFocusIsEditable, isTrue);
    await tester.tap(find.byKey(const ValueKey('track-color-done')));
    await tester.pumpAndSettle();
    expect(committed, 1);
    expect(cancelled, 0);

    await tester.tap(find.byKey(const ValueKey('track-color-swatch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('track-color-hex-field')),
      '#FEDCBA',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(committed, 1);
    expect(cancelled, 1);
    expect(find.byKey(const ValueKey('track-color-popover')), findsNothing);
  });

  testWidgets('track actions repeatedly opens and Rename remains functional', (
    tester,
  ) async {
    await pumpHeader(tester, onRename: (_) {});

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byTooltip('Track actions'));
      await tester.pumpAndSettle();
      expect(find.text('Track Actions'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('track-properties-rename')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track-name-editor')), findsOneWidget);
  });

  testWidgets('delete is available only inside Track Actions', (tester) async {
    var deletePresses = 0;
    await pumpHeader(
      tester,
      onRename: (_) {},
      onDeletePressed: () => deletePresses++,
    );

    expect(find.byTooltip('Delete track'), findsNothing);
    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('track-properties-delete')));
    await tester.pumpAndSettle();

    expect(deletePresses, 1);
    expect(
      find.byKey(const ValueKey('track-properties-popover')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Track FX opens a reorderable rack outside the actions menu', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      onRename: (_) {},
      trackFxRack: SizedBox(
        key: const ValueKey('test-filter-rack'),
        width: 320,
        child: ReorderableListView.builder(
          key: const ValueKey('test-fx-reorderable-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          onReorderItem: (_, _) {},
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('test-fx-slot-$index'),
            height: 32,
            child: Text('FX SLOT $index'),
          ),
        ),
      ),
    );

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('track-properties-button')));
      await tester.pumpAndSettle();
      expect(find.text('Track Actions'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('test-fx-reorderable-list')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('track-properties-fx')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('track-properties-popover')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('test-filter-rack')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('test-fx-reorderable-list')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('test-filter-rack')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Duplicate Track is available beside the separated delete action',
    (tester) async {
      var duplicatePresses = 0;
      await pumpHeader(
        tester,
        onRename: (_) {},
        onDuplicatePressed: () => duplicatePresses++,
      );

      expect(find.text('Duplicate Track'), findsNothing);
      await tester.tap(find.byTooltip('Track actions'));
      await tester.pumpAndSettle();

      final duplicate = find.byKey(
        const ValueKey('track-properties-duplicate'),
      );
      final delete = find.byKey(const ValueKey('track-properties-delete'));
      expect(duplicate, findsOneWidget);
      expect(delete, findsOneWidget);
      expect(
        tester.getTopLeft(duplicate).dy,
        lessThan(tester.getTopLeft(delete).dy),
      );

      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      expect(duplicatePresses, 1);
      expect(
        find.byKey(const ValueKey('track-properties-popover')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mixer row exposes symmetrical M/S controls and dB fader', (
    tester,
  ) async {
    var mutePresses = 0;
    var soloPresses = 0;
    await pumpHeader(
      tester,
      onRename: (_) {},
      volumeDb: -6.2,
      isMuted: true,
      onMutePressed: () => mutePresses++,
      onSoloPressed: () => soloPresses++,
    );

    final mute = find.byKey(const ValueKey('track-m-button'));
    final solo = find.byKey(const ValueKey('track-s-button'));
    expect(mute, findsOneWidget);
    expect(solo, findsOneWidget);
    expect(tester.getSize(mute), tester.getSize(solo));
    expect(find.text('-6.2 dB'), findsOneWidget);

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('track-volume-slider')),
    );
    expect(slider.min, -60);
    expect(slider.max, 6);

    await tester.tap(mute);
    await tester.tap(solo);
    expect(mutePresses, 1);
    expect(soloPresses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double-clicking volume fader requests unity reset', (
    tester,
  ) async {
    var resets = 0;
    await pumpHeader(
      tester,
      onRename: (_) {},
      volumeDb: -12,
      onVolumeReset: () => resets++,
    );

    final slider = find.byKey(const ValueKey('track-volume-slider'));
    await tester.tap(slider);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(slider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(resets, 1);
  });

  testWidgets('pan fader is bipolar and formats left, center, and right', (
    tester,
  ) async {
    await pumpHeader(tester, onRename: (_) {}, pan: -0.42);

    expect(find.byKey(const ValueKey('track-pan-slider')), findsNothing);
    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('track-pan-slider')),
    );
    expect(slider.min, -1);
    expect(slider.max, 1);
    expect(find.text('L 42'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await pumpHeader(tester, onRename: (_) {}, pan: 0);
    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await pumpHeader(tester, onRename: (_) {}, pan: 0.75);
    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();
    expect(find.text('R 75'), findsOneWidget);
  });

  testWidgets('double-clicking pan fader requests center reset', (
    tester,
  ) async {
    var resets = 0;
    await pumpHeader(
      tester,
      onRename: (_) {},
      pan: 0.6,
      onPanReset: () => resets++,
    );

    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();

    final slider = find.byKey(const ValueKey('track-pan-slider'));
    await tester.tap(slider);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(slider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(resets, 1);
  });

  testWidgets('only the compact reorder handle starts a track drag', (
    tester,
  ) async {
    var starts = 0;
    var updates = 0;
    var ends = 0;
    await pumpHeader(
      tester,
      onRename: (_) {},
      onReorderStarted: () => starts++,
      onReorderUpdated: (_) => updates++,
      onReorderEnded: () => ends++,
    );

    expect(find.byTooltip('Drag to reorder track'), findsOneWidget);
    final volumeGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('track-volume-slider'))),
    );
    await volumeGesture.moveBy(const Offset(20, 0));
    await volumeGesture.up();
    await tester.pump();
    expect(starts, 0);

    final reorderGesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('track-reorder-handle-Track 1')),
      ),
    );
    await reorderGesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await reorderGesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(starts, 1);
    expect(updates, greaterThan(0));
    expect(ends, 1);
    expect(tester.takeException(), isNull);
  });
}
