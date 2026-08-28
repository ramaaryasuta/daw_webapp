import 'package:flutter/material.dart';

import '../models/app_command.dart';

Future<void> showCommandsDialog(
  BuildContext context, {
  required List<AppCommand> commands,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => CommandsDialog(commands: commands),
  );
}

class CommandsDialog extends StatefulWidget {
  const CommandsDialog({super.key, required this.commands});

  final List<AppCommand> commands;

  @override
  State<CommandsDialog> createState() => _CommandsDialogState();
}

class _CommandsDialogState extends State<CommandsDialog> {
  static const _categoryOrder = <AppCommandCategory>[
    AppCommandCategory.editing,
    AppCommandCategory.timeline,
    AppCommandCategory.mixer,
    AppCommandCategory.file,
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  AppCommandCategory? _selectedCategory;
  AppCommand? _expandedCommand;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogHeight = screenSize.height * 0.78;
    final filteredCommands = _filterCommands(
      widget.commands,
      query: _query,
      category: _selectedCategory,
    );
    final groupedCommands = _groupCommands(filteredCommands);
    final categories = [
      for (final category in _categoryOrder)
        if (widget.commands.any((command) => command.category == category))
          category,
    ];

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxDialogHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 10, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commands',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keyboard, mouse, and editor actions',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('commands-search-field'),
                    controller: _searchController,
                    autofocus: true,
                    maxLines: 1,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search commands...',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey('commands-search-clear'),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _expandedCommand = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 17),
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _expandedCommand = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryChip(
                                label: 'All',
                                selected: _selectedCategory == null,
                                onSelected: () => _selectCategory(null),
                              ),
                              for (final category in categories) ...[
                                const SizedBox(width: 6),
                                _CategoryChip(
                                  label: category.label,
                                  selected: _selectedCategory == category,
                                  onSelected: () => _selectCategory(category),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${filteredCommands.length} ${filteredCommands.length == 1 ? 'command' : 'commands'}',
                        key: const ValueKey('commands-result-count'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Flexible(
              child: filteredCommands.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 26,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            const Text('No commands found'),
                            const SizedBox(height: 3),
                            Text(
                              'Try another search or category.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      children: [
                        for (final group in groupedCommands.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                            child: Text(
                              group.key.label.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < group.value.length;
                                  index++
                                )
                                  _CommandRow(
                                    command: group.value[index],
                                    expanded:
                                        _expandedCommand == group.value[index],
                                    showDivider: index < group.value.length - 1,
                                    onTap: () =>
                                        _toggleExpanded(group.value[index]),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCategory(AppCommandCategory? category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _expandedCommand = null;
    });
  }

  void _toggleExpanded(AppCommand command) {
    setState(() {
      _expandedCommand = _expandedCommand == command ? null : command;
    });
  }

  List<AppCommand> _filterCommands(
    List<AppCommand> commands, {
    required String query,
    required AppCommandCategory? category,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return [
      for (final command in commands)
        if ((category == null || command.category == category) &&
            (normalizedQuery.isEmpty ||
                [
                  command.title,
                  command.description,
                  command.shortcutParts.join(' '),
                  command.category.label,
                  command.searchTerms.join(' '),
                  command.details ?? '',
                  command.usageSteps.join(' '),
                  command.tip ?? '',
                ].join(' ').toLowerCase().contains(normalizedQuery)))
          command,
    ];
  }

  Map<AppCommandCategory, List<AppCommand>> _groupCommands(
    List<AppCommand> commands,
  ) {
    return {
      for (final category in _categoryOrder)
        if (commands.any((command) => command.category == category))
          category: [
            for (final command in commands)
              if (command.category == category) command,
          ],
    };
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      key: ValueKey('commands-category-$label'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.primaryContainer,
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.expanded,
    required this.showDivider,
    required this.onTap,
  });

  final AppCommand command;
  final bool expanded;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('command-row-${command.title}'),
      color: expanded ? colorScheme.surfaceContainerLow : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.045),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    command.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: expanded ? FontWeight.w700 : FontWeight.w600,
                    ),
                  );
                  final shortcut = _ShortcutLabel(parts: command.shortcutParts);
                  final chevron = AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                  if (constraints.maxWidth < 440) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: title),
                            chevron,
                          ],
                        ),
                        const SizedBox(height: 7),
                        shortcut,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 16),
                      shortcut,
                      const SizedBox(width: 8),
                      chevron,
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                command.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: expanded
                    ? _ExpandedCommandDetails(command: command)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedCommandDetails extends StatelessWidget {
  const _ExpandedCommandDetails({required this.command});

  final AppCommand command;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 11),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              command.details ?? command.description,
              key: ValueKey('command-details-${command.title}'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            if (command.usageSteps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'How to use',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              for (var index = 0; index < command.usageSteps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${index + 1}. ${command.usageSteps[index]}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
            if (command.tip case final tip?) ...[
              const SizedBox(height: 9),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Tip  ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: tip),
                  ],
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortcutLabel extends StatelessWidget {
  const _ShortcutLabel({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var index = 0; index < parts.length; index++) ...[
          _ShortcutBadge(label: parts[index]),
          if (index < parts.length - 1)
            Text(
              '+',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
