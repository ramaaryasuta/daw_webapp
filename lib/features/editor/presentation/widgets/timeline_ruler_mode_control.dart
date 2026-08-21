import 'package:flutter/material.dart';

import '../models/timeline_ruler_mode.dart';

class TimelineRulerModeControl extends StatelessWidget {
  const TimelineRulerModeControl({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TimelineRulerMode mode;
  final ValueChanged<TimelineRulerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<TimelineRulerMode>(
      tooltip: 'Ruler display',
      initialValue: mode,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final value in TimelineRulerMode.values)
          PopupMenuItem(value: value, child: Text(value.label)),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 9, right: 5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.straighten_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              mode.compactLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
