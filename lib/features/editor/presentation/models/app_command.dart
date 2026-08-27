enum AppCommandCategory {
  editing('Editing'),
  timeline('Timeline');

  const AppCommandCategory(this.label);

  final String label;
}

class AppCommand {
  const AppCommand({
    required this.title,
    required this.description,
    required this.shortcutParts,
    required this.category,
  });

  final String title;
  final String description;
  final List<String> shortcutParts;
  final AppCommandCategory category;
}

abstract final class EditorCommands {
  static const undo = AppCommand(
    title: 'Undo',
    description: 'Undo the most recent editing action.',
    shortcutParts: ['Ctrl', 'Z'],
    category: AppCommandCategory.editing,
  );

  static const redo = AppCommand(
    title: 'Redo',
    description:
        'Redo the most recently undone editing action. Ctrl + Y is also supported.',
    shortcutParts: ['Ctrl', 'Shift', 'Z'],
    category: AppCommandCategory.editing,
  );

  static const copyAudioClip = AppCommand(
    title: 'Copy Clip(s)',
    description: 'Copy all selected audio clips.',
    shortcutParts: ['Ctrl', 'C'],
    category: AppCommandCategory.editing,
  );

  static const pasteAudioClip = AppCommand(
    title: 'Paste Clip(s)',
    description: 'Paste copied audio clips at the playhead.',
    shortcutParts: ['Ctrl', 'V'],
    category: AppCommandCategory.editing,
  );

  static const duplicateAudioClip = AppCommand(
    title: 'Duplicate Clip(s)',
    description: 'Duplicate the selected clip group after its visible end.',
    shortcutParts: ['Ctrl', 'D'],
    category: AppCommandCategory.editing,
  );

  static const playPause = AppCommand(
    title: 'Play / Pause',
    description: 'Start or pause playback at the current playhead position.',
    shortcutParts: ['Space'],
    category: AppCommandCategory.timeline,
  );

  static const toggleLoop = AppCommand(
    title: 'Toggle Loop',
    description:
        'Enable or disable playback looping for the selected cycle region.',
    shortcutParts: ['L'],
    category: AppCommandCategory.timeline,
  );

  static const setLoopRegion = AppCommand(
    title: 'Set Loop Region',
    description: 'Create or resize the playback loop region.',
    shortcutParts: ['Drag Timeline Ruler'],
    category: AppCommandCategory.timeline,
  );

  static const zoomTimeline = AppCommand(
    title: 'Zoom Timeline',
    description: 'Zoom the timeline horizontally around the pointer position.',
    shortcutParts: ['Ctrl', 'Mouse Wheel'],
    category: AppCommandCategory.timeline,
  );

  static const scrollTimeline = AppCommand(
    title: 'Scroll Timeline',
    description: 'Scroll horizontally through the timeline.',
    shortcutParts: ['Shift', 'Mouse Wheel'],
    category: AppCommandCategory.timeline,
  );

  static const panTimeline = AppCommand(
    title: 'Pan Timeline',
    description: 'Grab and pan the timeline horizontally.',
    shortcutParts: ['Middle Mouse', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const moveAudioClip = AppCommand(
    title: 'Move Clip(s)',
    description: 'Move selected audio clips in time or between tracks.',
    shortcutParts: ['Left Mouse', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const trimAudioClip = AppCommand(
    title: 'Trim Audio Clip',
    description: 'Trim the visible start or end of an audio clip.',
    shortcutParts: ['Drag Clip Edge'],
    category: AppCommandCategory.timeline,
  );

  static const splitAudioClip = AppCommand(
    title: 'Split Clip',
    description: 'Split the selected audio clip at the playhead.',
    shortcutParts: ['S'],
    category: AppCommandCategory.editing,
  );

  static const deleteAudioClip = AppCommand(
    title: 'Delete Clip(s)',
    description: 'Remove all selected audio clips from the arrangement.',
    shortcutParts: ['Delete / Backspace'],
    category: AppCommandCategory.editing,
  );

  static const clipProperties = AppCommand(
    title: 'Clip Properties',
    description: 'Open Fade In / Fade Out properties for the audio clip.',
    shortcutParts: ['Double-click Audio Clip'],
    category: AppCommandCategory.editing,
  );

  static const multiSelectClip = AppCommand(
    title: 'Multi-Select Clip',
    description: 'Add or remove an audio clip from the current selection.',
    shortcutParts: ['Ctrl', 'Click'],
    category: AppCommandCategory.editing,
  );

  static const marqueeSelect = AppCommand(
    title: 'Marquee Select',
    description: 'Select multiple audio clips with a selection rectangle.',
    shortcutParts: ['Drag Empty Timeline'],
    category: AppCommandCategory.timeline,
  );

  static const renameTrack = AppCommand(
    title: 'Rename Track',
    description: 'Rename a track directly in its header.',
    shortcutParts: ['Double-click Track Name'],
    category: AppCommandCategory.editing,
  );

  static const changeTrackColor = AppCommand(
    title: 'Change Track Color',
    description: 'Choose the color used by a track and all of its clips.',
    shortcutParts: ['Click Track Color'],
    category: AppCommandCategory.editing,
  );

  static const snapToGrid = AppCommand(
    title: 'Snap to Grid',
    description:
        'Align clip movement, trimming, loop boundaries, and timeline seeking to the selected musical grid.',
    shortcutParts: ['Toolbar', 'Snap'],
    category: AppCommandCategory.timeline,
  );

  static const temporarilyDisableSnap = AppCommand(
    title: 'Temporarily Disable Snap',
    description: 'Temporarily move or trim freely without snapping.',
    shortcutParts: ['Alt', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const all = <AppCommand>[
    undo,
    redo,
    copyAudioClip,
    pasteAudioClip,
    duplicateAudioClip,
    splitAudioClip,
    deleteAudioClip,
    multiSelectClip,
    clipProperties,
    renameTrack,
    changeTrackColor,
    playPause,
    toggleLoop,
    setLoopRegion,
    snapToGrid,
    temporarilyDisableSnap,
    zoomTimeline,
    scrollTimeline,
    panTimeline,
    moveAudioClip,
    marqueeSelect,
    trimAudioClip,
  ];
}
