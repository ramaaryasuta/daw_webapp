import 'package:daw_webapp/features/editor/presentation/models/app_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Help commands expose searchable project time signature', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Time Signature',
    );

    expect(command.shortcutParts, ['Toolbar', 'Time Signature']);
    expect(command.description, contains('4/4, 3/4, or 6/8'));
    expect(command.searchTerms, containsAll(['time', 'signature', 'meter']));
  });

  test('command metadata centralizes expandable guidance and categories', () {
    expect(AppCommandCategory.file.label, 'Project');
    expect(EditorCommands.splitAudioClip.details, isNotEmpty);
    expect(EditorCommands.splitAudioClip.usageSteps, hasLength(3));
    expect(EditorCommands.splitAudioClip.tip, contains('Snap'));
    expect(
      EditorCommands.trackMixerControls.category,
      AppCommandCategory.mixer,
    );
  });

  test('Help commands define portable project Save and Open', () {
    final save = EditorCommands.all.singleWhere(
      (command) => command.title == 'Save Project',
    );
    final open = EditorCommands.all.singleWhere(
      (command) => command.title == 'Open Project',
    );

    expect(save.shortcutParts, ['File', 'Save Project...']);
    expect(
      save.description,
      'Save the project and its audio sources as a portable .fldawproj file.',
    );
    expect(open.shortcutParts, ['File', 'Open Project...']);
    expect(open.description, 'Open a portable .fldawproj project file.');
  });

  test('Help commands define marker gestures once', () {
    final markerCommands = EditorCommands.all.where(
      (command) => command.title.contains('Marker'),
    );

    expect(markerCommands.map((command) => command.title), [
      'Add Marker',
      'Open Marker Properties',
      'Move Marker',
      'Jump to Marker',
    ]);
    expect(EditorCommands.addMarker.shortcutParts, [
      'Double-click Marker Lane',
    ]);
    expect(EditorCommands.moveMarker.shortcutParts, ['Drag Marker']);
  });

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

  test('Help commands describe creating and removing crossfades', () {
    final create = EditorCommands.all.singleWhere(
      (command) => command.title == 'Create Crossfade',
    );
    final remove = EditorCommands.all.singleWhere(
      (command) => command.title == 'Remove Crossfade',
    );

    expect(create.shortcutParts, ['Edit', 'Create Crossfade']);
    expect(
      create.description,
      'Create a fade transition between two selected overlapping clips.',
    );
    expect(remove.shortcutParts, ['Edit', 'Remove Crossfade']);
    expect(
      remove.description,
      'Remove the crossfade between the selected clips.',
    );
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
      'Open Gain and Fade In / Fade Out properties for the audio clip.',
    );
  });

  test('Help commands describe two-dimensional clip movement', () {
    final command = EditorCommands.all.singleWhere(
      (command) => command.title == 'Move Clip(s)',
    );

    expect(command.shortcutParts, ['Left Mouse', 'Drag']);
    expect(
      command.description,
      'Move selected audio clips in time or between tracks.',
    );
  });

  test('Help commands document add and delete track UI actions', () {
    final add = EditorCommands.all.singleWhere(
      (command) => command.title == 'Add Audio Track',
    );
    final delete = EditorCommands.all.singleWhere(
      (command) => command.title == 'Delete Track',
    );

    expect(add.shortcutParts, ['Tracks + Button']);
    expect(add.description, 'Create a new empty audio track.');
    expect(delete.shortcutParts, ['Track Actions', 'Delete Track']);
    expect(delete.description, contains('clips'));
  });

  test('Help commands define the track reorder handle gesture once', () {
    final matches = EditorCommands.all.where(
      (command) => command.title == 'Reorder Track',
    );

    expect(matches, hasLength(1));
    expect(matches.single.shortcutParts, ['Drag Track Handle']);
    expect(
      matches.single.description,
      'Change the vertical order of an audio track.',
    );
  });
}
