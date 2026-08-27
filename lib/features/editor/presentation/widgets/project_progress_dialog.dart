import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ProjectOperationProgress {
  const ProjectOperationProgress({
    required this.title,
    required this.status,
    required this.projectName,
    this.value,
  });

  final String title;
  final String status;
  final String projectName;
  final double? value;
}

class ProjectProgressDialog extends StatelessWidget {
  const ProjectProgressDialog({super.key, required this.progress});

  final ValueListenable<ProjectOperationProgress> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProjectOperationProgress>(
      valueListenable: progress,
      builder: (context, value, _) {
        return PopScope(
          canPop: false,
          child: Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    Text(value.status),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: value.value),
                    const SizedBox(height: 14),
                    Text(
                      value.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
