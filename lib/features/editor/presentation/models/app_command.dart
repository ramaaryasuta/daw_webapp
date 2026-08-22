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

  static const playPause = AppCommand(
    title: 'Play / Pause',
    description: 'Start or pause playback at the current playhead position.',
    shortcutParts: ['Space'],
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
    title: 'Move Audio Clip',
    description: 'Move an audio clip horizontally on the timeline.',
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
        'Align clip movement, trimming, and timeline seeking to the selected musical grid.',
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
    splitAudioClip,
    renameTrack,
    changeTrackColor,
    playPause,
    snapToGrid,
    temporarilyDisableSnap,
    zoomTimeline,
    scrollTimeline,
    panTimeline,
    moveAudioClip,
    trimAudioClip,
  ];
}
