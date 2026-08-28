import 'package:flutter/material.dart';

import '../../domain/timeline_section.dart';
import '../editor_shortcut_policy.dart';
import '../track_color_palette.dart';

class SectionPropertiesPopover extends StatefulWidget {
  const SectionPropertiesPopover({
    super.key,
    required this.section,
    required this.onRename,
    required this.onColorSelected,
    required this.onDelete,
  });

  final TimelineSection section;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onDelete;

  @override
  State<SectionPropertiesPopover> createState() =>
      _SectionPropertiesPopoverState();
}

class _SectionPropertiesPopoverState extends State<SectionPropertiesPopover> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late String _lastCommittedName;

  @override
  void initState() {
    super.initState();
    _lastCommittedName = widget.section.name;
    _nameController = TextEditingController(text: widget.section.name);
    _nameFocusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SectionPropertiesPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_nameFocusNode.hasFocus && widget.section.name != _lastCommittedName) {
      _lastCommittedName = widget.section.name;
      _nameController.text = widget.section.name;
    }
  }

  @override
  void dispose() {
    _nameFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_nameFocusNode.hasFocus) {
      _commitName();
    }
  }

  void _commitName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameController.text = _lastCommittedName;
      return;
    }
    if (name != _lastCommittedName) {
      _lastCommittedName = name;
      widget.onRename(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final section = widget.section;
    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 286,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 48, child: Text('Name')),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('section-name-field'),
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        autofocus: true,
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) {
                          _commitName();
                          _nameFocusNode.unfocus();
                        },
                        onTapOutside: (_) => _nameFocusNode.unfocus(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 48, child: Text('Color')),
                    Expanded(
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final preset in trackColorPresets)
                            Tooltip(
                              message: preset.label,
                              child: InkResponse(
                                key: ValueKey(
                                  'section-color-${preset.colorValue}',
                                ),
                                onTap: () =>
                                    widget.onColorSelected(preset.colorValue),
                                radius: 14,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: preset.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          preset.colorValue == section.colorArgb
                                          ? colors.onSurface
                                          : colors.outlineVariant,
                                      width:
                                          preset.colorValue == section.colorArgb
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TimeRow(label: 'Start', seconds: section.startTime),
                const SizedBox(height: 4),
                _TimeRow(label: 'End', seconds: section.endTime),
                const SizedBox(height: 4),
                _TimeRow(label: 'Length', seconds: section.duration),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('delete-section-button'),
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Delete Section'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.seconds});

  final String label;
  final double seconds;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Text(
          formatSectionTime(seconds),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

String formatSectionTime(double seconds) {
  final milliseconds = (seconds * 1000).round();
  final hours = milliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (milliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final wholeSeconds = (milliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final millis = milliseconds % 1000;
  final hourPrefix = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
  return '$hourPrefix${minutes.toString().padLeft(2, '0')}:'
      '${wholeSeconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}
