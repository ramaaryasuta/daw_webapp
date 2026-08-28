import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/snap_controller.dart';
import '../../application/editor_controller.dart';
import '../../domain/snap_settings.dart';

class SnapControl extends ConsumerWidget {
  const SnapControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(snapControllerProvider);
    final controller = ref.read(snapControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: settings.enabled
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : colorScheme.surfaceContainerLow,
        border: Border.all(
          color: settings.enabled
              ? colorScheme.primary.withValues(alpha: 0.75)
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: settings.enabled ? 'Disable Snap' : 'Enable Snap',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            color: settings.enabled
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            onPressed: () {
              controller.toggleEnabled();
              ref
                  .read(editorControllerProvider.notifier)
                  .markPersistentSettingsChanged();
            },
            icon: Icon(
              settings.enabled ? Icons.grid_4x4 : Icons.grid_off,
              size: 18,
            ),
          ),
          Container(width: 1, height: 20, color: colorScheme.outlineVariant),
          PopupMenuButton<SnapSubdivision>(
            tooltip: 'Snap resolution',
            initialValue: settings.subdivision,
            onSelected: (subdivision) {
              if (subdivision == settings.subdivision) return;
              controller.setSubdivision(subdivision);
              ref
                  .read(editorControllerProvider.notifier)
                  .markPersistentSettingsChanged();
            },
            itemBuilder: (context) => [
              for (final subdivision in SnapSubdivision.values)
                PopupMenuItem(
                  value: subdivision,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: subdivision == settings.subdivision
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: colorScheme.primary,
                              )
                            : null,
                      ),
                      Text(subdivision.label),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.enabled
                        ? settings.subdivision.label
                        : 'Off - ${settings.subdivision.label}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: settings.enabled
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
