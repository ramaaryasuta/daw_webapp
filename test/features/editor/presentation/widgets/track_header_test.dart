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
              volume: 1,
              isMuted: false,
              isSolo: false,
              isSelected: false,
              onTap: () {},
              onRename: onRename,
              onColorEditStarted: onColorEditStarted ?? () {},
              onColorPreviewed: onColorPreviewed ?? (_) {},
              onColorEditCommitted: onColorEditCommitted ?? () {},
              onColorEditCancelled: onColorEditCancelled ?? () {},
              onMutePressed: () {},
              onSoloPressed: () {},
              onDeletePressed: () {},
              onVolumeChangeStart: (_) {},
              onVolumeChanged: (_) {},
              onVolumeChangeEnd: (_) {},
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
      expect(find.text('Rename'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Track actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track-name-editor')), findsOneWidget);
  });
}
