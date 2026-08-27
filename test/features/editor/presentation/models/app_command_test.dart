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

  test('Help commands define Delete Clip(s) keyboard shortcuts', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Delete Clip(s)',
    );

    expect(command.shortcutParts, ['Delete / Backspace']);
    expect(
      command.description,
      'Remove all selected audio clips from the arrangement.',
    );
  });

  test('Help commands define clip clipboard shortcuts and descriptions', () {
    final copy = EditorCommands.all.singleWhere(
      (command) => command.title == 'Copy Clip(s)',
    );
    final paste = EditorCommands.all.singleWhere(
      (command) => command.title == 'Paste Clip(s)',
    );
    final duplicate = EditorCommands.all.singleWhere(
      (command) => command.title == 'Duplicate Clip(s)',
    );

    expect(copy.shortcutParts, ['Ctrl', 'C']);
    expect(copy.description, 'Copy all selected audio clips.');
    expect(paste.shortcutParts, ['Ctrl', 'V']);
    expect(paste.description, 'Paste copied audio clips at the playhead.');
    expect(duplicate.shortcutParts, ['Ctrl', 'D']);
    expect(
      duplicate.description,
      'Duplicate the selected clip group after its visible end.',
    );
  });

  test('Help commands define multi-select and marquee gestures', () {
    final multiSelect = EditorCommands.all.singleWhere(
      (command) => command.title == 'Multi-Select Clip',
    );
    final marquee = EditorCommands.all.singleWhere(
      (command) => command.title == 'Marquee Select',
    );

    expect(multiSelect.shortcutParts, ['Ctrl', 'Click']);
    expect(multiSelect.description, contains('Add or remove'));
    expect(marquee.shortcutParts, ['Drag Empty Timeline']);
    expect(marquee.description, contains('selection rectangle'));
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
