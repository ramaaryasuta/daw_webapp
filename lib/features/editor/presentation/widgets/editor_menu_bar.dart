import 'package:flutter/material.dart';

class EditorMenuSection {
  const EditorMenuSection({required this.label, required this.actions});

  final String label;
  final List<EditorMenuAction> actions;
}

class EditorMenuAction {
  const EditorMenuAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.separatorBefore = false,
  });

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool separatorBefore;
}

class EditorMenuBar extends StatelessWidget {
  const EditorMenuBar({super.key, required this.sections});

  final List<EditorMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MenuBar(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
            elevation: const WidgetStatePropertyAll(0),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          children: [
            for (final section in sections)
              SubmenuButton(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 30)),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                menuChildren: [
                  for (final action in section.actions) ...[
                    if (action.separatorBefore) const Divider(height: 1),
                    MenuItemButton(
                      leadingIcon: action.icon == null
                          ? null
                          : Icon(action.icon, size: 18),
                      onPressed: action.onSelected,
                      child: Text(action.label),
                    ),
                  ],
                ],
                child: Text(section.label),
              ),
          ],
        ),
      ),
    );
  }
}
