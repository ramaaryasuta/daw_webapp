import 'package:daw_webapp/features/editor/presentation/models/app_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Help commands define the Space Play / Pause shortcut', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Play / Pause',
    );

    expect(command.shortcutParts, ['Space']);
    expect(
      command.description,
      'Start or pause playback at the current playhead position.',
    );
  });

  test('Help commands define Undo and primary Redo shortcuts', () {
    final undo = EditorCommands.all.singleWhere(
      (command) => command.title == 'Undo',
    );
    final redo = EditorCommands.all.singleWhere(
      (command) => command.title == 'Redo',
    );

    expect(undo.shortcutParts, ['Ctrl', 'Z']);
    expect(undo.description, 'Undo the most recent editing action.');
    expect(redo.shortcutParts, ['Ctrl', 'Shift', 'Z']);
    expect(redo.description, contains('Ctrl + Y'));
  });
}
