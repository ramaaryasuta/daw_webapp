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
}
