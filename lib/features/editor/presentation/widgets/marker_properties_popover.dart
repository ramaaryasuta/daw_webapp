import 'package:flutter/material.dart';

import '../../domain/timeline_marker.dart';
import '../editor_shortcut_policy.dart';
import '../track_color_palette.dart';

class MarkerPropertiesPopover extends StatefulWidget {
  const MarkerPropertiesPopover({
    super.key,
    required this.marker,
    required this.onRename,
    required this.onColorSelected,
    required this.onDelete,
  });

  final TimelineMarker marker;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onDelete;

  @override
  State<MarkerPropertiesPopover> createState() =>
      _MarkerPropertiesPopoverState();
}

class _MarkerPropertiesPopoverState extends State<MarkerPropertiesPopover> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late String _lastCommittedName;

  @override
  void initState() {
    super.initState();
    _lastCommittedName = widget.marker.name;
    _nameController = TextEditingController(text: widget.marker.name);
    _nameFocusNode = FocusNode()..addListener(_handleNameFocusChanged);
  }

  @override
  void didUpdateWidget(covariant MarkerPropertiesPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_nameFocusNode.hasFocus && widget.marker.name != _lastCommittedName) {
      _lastCommittedName = widget.marker.name;
      _nameController.text = widget.marker.name;
    }
  }

  @override
  void dispose() {
    _nameFocusNode
      ..removeListener(_handleNameFocusChanged)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameFocusChanged() {
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
    if (name == _lastCommittedName) {
      return;
    }
    _lastCommittedName = name;
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 270,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marker',
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
                        key: const ValueKey('marker-name-field'),
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
                                  'marker-color-${preset.colorValue}',
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
                                          preset.colorValue ==
                                              widget.marker.colorArgb
                                          ? colorScheme.onSurface
                                          : colorScheme.outlineVariant,
                                      width:
                                          preset.colorValue ==
                                              widget.marker.colorArgb
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
                Row(
                  children: [
                    const SizedBox(width: 48, child: Text('Time')),
                    Text(
                      _formatMarkerTime(widget.marker.timeSeconds),
                      key: const ValueKey('marker-time-value'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('delete-marker-button'),
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Delete Marker'),
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

String _formatMarkerTime(double seconds) {
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
