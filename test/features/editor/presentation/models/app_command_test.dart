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

  test('Help commands define Delete Clip keyboard shortcuts', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Delete Clip',
    );

    expect(command.shortcutParts, ['Delete / Backspace']);
    expect(
      command.description,
      'Remove the selected audio clip from the arrangement.',
    );
  });

  test('Help commands define the Clip Properties gesture', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Clip Properties',
    );

    expect(command.shortcutParts, ['Double-click Audio Clip']);
    expect(
      command.description,
      'Open Fade In / Fade Out properties for the audio clip.',
    );
  });
}
