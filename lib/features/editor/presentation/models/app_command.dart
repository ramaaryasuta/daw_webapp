enum AppCommandCategory {
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

  static const all = <AppCommand>[
    zoomTimeline,
    scrollTimeline,
    panTimeline,
    moveAudioClip,
  ];
}
