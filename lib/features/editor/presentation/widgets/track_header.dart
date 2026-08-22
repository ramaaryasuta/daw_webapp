import 'package:flutter/material.dart';

const double trackHeaderWidth = 280;
const double trackHeight = 110;

class TrackHeader extends StatelessWidget {
  const TrackHeader({
    super.key,
    required this.name,
    required this.volume,
    required this.isMuted,
    required this.isSolo,
    required this.isSelected,
    required this.onTap,
    required this.onMutePressed,
    required this.onSoloPressed,
    required this.onDeletePressed,
    required this.onVolumeChangeStart,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
  });

  final String name;
  final double volume;

  final bool isMuted;
  final bool isSolo;
  final bool isSelected;

  final VoidCallback onTap;
  final VoidCallback onMutePressed;
  final VoidCallback onSoloPressed;
  final VoidCallback onDeletePressed;

  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeStart;
  final ValueChanged<double> onVolumeChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: trackHeaderWidth,
          height: trackHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant),
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Delete track',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: onDeletePressed,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  _TrackButton(
                    label: 'M',
                    active: isMuted,
                    onPressed: onMutePressed,
                  ),

                  const SizedBox(width: 6),

                  _TrackButton(
                    label: 'S',
                    active: isSolo,
                    onPressed: onSoloPressed,
                  ),

                  const SizedBox(width: 8),

                  const Icon(Icons.volume_down, size: 18),

                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      onChangeStart: onVolumeChangeStart,
                      onChanged: onVolumeChanged,
                      onChangeEnd: onVolumeChangeEnd,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 28,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Text(label),
      ),
    );
  }
}
