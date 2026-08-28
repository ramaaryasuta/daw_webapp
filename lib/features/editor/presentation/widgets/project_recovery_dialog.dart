import 'package:flutter/material.dart';

import '../../infrastructure/project_io/project_autosave.dart';

enum ProjectRecoveryChoice { discard, recover }

Future<ProjectRecoveryChoice?> showProjectRecoveryDialog(
  BuildContext context, {
  required AutosaveRecovery recovery,
}) {
  return showDialog<ProjectRecoveryChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProjectRecoveryDialog(recovery: recovery),
  );
}

class _ProjectRecoveryDialog extends StatelessWidget {
  const _ProjectRecoveryDialog({required this.recovery});

  final AutosaveRecovery recovery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final localTime = recovery.savedAt.toLocal();
    final time =
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    return PopScope(
      canPop: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.restore_outlined,
                        color: colors.onPrimaryContainer,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recover Project?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('An autosaved project was found.'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recovery.manifest.project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last local save: $time',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProjectRecoveryChoice.discard),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProjectRecoveryChoice.recover),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Recover Project'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
