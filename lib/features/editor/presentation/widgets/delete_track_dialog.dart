import 'package:flutter/material.dart';

Future<bool> showDeleteTrackConfirmation(
  BuildContext context, {
  required int clipCount,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final clipLabel = clipCount == 1 ? 'audio clip' : 'audio clips';
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Track?'),
          content: Text(
            'This track contains $clipCount $clipLabel.\n'
            'Deleting the track will remove these clips from the arrangement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-delete-track'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Track and Clips'),
            ),
          ],
        ),
      ) ??
      false;
}
