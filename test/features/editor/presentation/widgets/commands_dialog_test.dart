import 'package:daw_webapp/features/editor/presentation/models/app_command.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/commands_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCommands(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CommandsDialog(commands: EditorCommands.all)),
      ),
    );
  }

  testWidgets('filters reusable commands by title, shortcut, and description', (
    tester,
  ) async {
    await pumpCommands(tester);
    final search = find.byKey(const ValueKey('commands-search-field'));

    await tester.enterText(search, 'fade');
    await tester.pump();
    expect(find.text('Clip Properties'), findsOneWidget);
    expect(find.text('Play / Pause'), findsNothing);

    await tester.enterText(search, 'SPACE');
    await tester.pump();
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Clip Properties'), findsNothing);

    await tester.enterText(search, 'wheel');
    await tester.pump();
    expect(find.text('Zoom Timeline'), findsOneWidget);
    expect(find.text('Scroll Timeline'), findsOneWidget);

    await tester.enterText(search, 'marker');
    await tester.pump();
    expect(find.text('Add Marker'), findsOneWidget);
    expect(find.text('Jump to Marker'), findsOneWidget);

    await tester.enterText(search, 'properties');
    await tester.pump();
    expect(find.text('Open Marker Properties'), findsOneWidget);

    await tester.enterText(search, 'verse');
    await tester.pump();
    expect(find.text('Add Marker'), findsOneWidget);
  });

  testWidgets('shows no-result state and clears the query', (tester) async {
    await pumpCommands(tester);
    final search = find.byKey(const ValueKey('commands-search-field'));

    await tester.enterText(search, 'not a real command');
    await tester.pump();
    expect(find.text('No commands found'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('commands-search-clear')));
    await tester.pump();
    expect(find.text('No commands found'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
  });

  testWidgets('combines category filters with live search', (tester) async {
    await pumpCommands(tester);

    await tester.tap(find.byKey(const ValueKey('commands-category-Editing')));
    await tester.pump();
    expect(find.text('Split Clip'), findsOneWidget);
    expect(find.text('Play / Pause'), findsNothing);
    expect(find.text('Save Project'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('commands-search-field')),
      'split',
    );
    await tester.pump();
    expect(find.text('Split Clip'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('commands-category-Timeline')));
    await tester.pump();
    expect(find.text('No commands found'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('commands-search-clear')));
    await tester.pump();
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Split Clip'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('commands-category-Mixer')));
    await tester.pump();
    expect(find.text('Track Mixer Controls'), findsOneWidget);
    expect(find.byKey(const ValueKey('command-row-Mixer')), findsOneWidget);
    expect(find.text('Track Fader'), findsOneWidget);
    expect(find.text('Track Pan'), findsOneWidget);
    expect(find.text('Play / Pause'), findsNothing);

    final projectCategory = find.byKey(
      const ValueKey('commands-category-Project'),
    );
    await tester.ensureVisible(projectCategory);
    await tester.pump();
    await tester.tap(projectCategory);
    await tester.pump();
    expect(find.text('Save Project'), findsOneWidget);
    expect(find.text('Open Project'), findsOneWidget);
  });

  testWidgets('expands one command from centralized guidance metadata', (
    tester,
  ) async {
    await pumpCommands(tester);
    await tester.enterText(
      find.byKey(const ValueKey('commands-search-field')),
      'position the playhead before splitting',
    );
    await tester.pump();
    expect(find.text('Split Clip'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('command-row-Split Clip')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('command-details-Split Clip')),
      findsOneWidget,
    );
    expect(find.text('How to use'), findsOneWidget);
    expect(find.text('1. Select one clip.'), findsOneWidget);
    expect(find.textContaining('Snap can be used'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('command-row-Split Clip')));
    await tester.pumpAndSettle();
    expect(find.text('How to use'), findsNothing);
  });

  testWidgets('keeps search focused and stays compact at narrow widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpCommands(tester);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(9));
  });
}
