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

  static const all = <AppCommand>[zoomTimeline];
}
