import 'package:daw_webapp/features/editor/presentation/editor_shortcut_policy.dart';
import 'package:daw_webapp/features/editor/presentation/intents/play_pause_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Space runs the editor action with ordinary editor focus', (
    tester,
  ) async {
    var invocationCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (editorContext) => Shortcuts(
            shortcuts: const {PlayPauseShortcutActivator(): PlayPauseIntent()},
            child: Actions(
              actions: {
                PlayPauseIntent: CallbackAction<PlayPauseIntent>(
                  onInvoke: (_) {
                    if (EditorShortcutPolicy.canHandleTransportShortcut(
                      editorContext,
                    )) {
                      invocationCount++;
                    }
                    return null;
                  },
                ),
              },
              child: const Focus(
                autofocus: true,
                child: Scaffold(body: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(invocationCount, 1);
  });

  testWidgets('Space remains text input while an EditableText has focus', (
    tester,
  ) async {
    var invocationCount = 0;
    final textController = TextEditingController(text: '120');
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (editorContext) => Shortcuts(
            shortcuts: const {PlayPauseShortcutActivator(): PlayPauseIntent()},
            child: Actions(
              actions: {
                PlayPauseIntent: CallbackAction<PlayPauseIntent>(
                  onInvoke: (_) {
                    if (EditorShortcutPolicy.canHandleTransportShortcut(
                      editorContext,
                    )) {
                      invocationCount++;
                    }
                    return null;
                  },
                ),
              },
              child: Scaffold(
                body: TextField(controller: textController, autofocus: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    textController.selection = const TextSelection.collapsed(offset: 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(invocationCount, 0);
    expect(textController.text, '120');
    expect(EditorShortcutPolicy.primaryFocusOwnsSpace, isTrue);
  });

  testWidgets('editor transport shortcut is disabled behind a dialog', (
    tester,
  ) async {
    late BuildContext editorContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            editorContext = context;
            return Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: Text('Dialog')),
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      EditorShortcutPolicy.canHandleTransportShortcut(editorContext),
      isFalse,
    );
  });
}
