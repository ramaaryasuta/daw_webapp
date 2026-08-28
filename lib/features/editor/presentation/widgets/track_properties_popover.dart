import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/track_mixer.dart';
import '../editor_shortcut_policy.dart';
import '../track_color_palette.dart';

class TrackPropertiesPopover extends StatelessWidget {
  const TrackPropertiesPopover({
    super.key,
    required this.trackName,
    required this.colorValue,
    required this.pan,
    required this.onRename,
    required this.onColorSelected,
    required this.onPanChangeStart,
    required this.onPanChanged,
    required this.onPanChangeEnd,
    required this.onPanReset,
    required this.onDuplicate,
    this.onTrackFx,
    required this.onDelete,
  });

  final String trackName;
  final int colorValue;
  final double pan;
  final VoidCallback onRename;
  final ValueChanged<int> onColorSelected;
  final ValueChanged<double> onPanChangeStart;
  final ValueChanged<double> onPanChanged;
  final ValueChanged<double> onPanChangeEnd;
  final VoidCallback onPanReset;
  final VoidCallback onDuplicate;
  final VoidCallback? onTrackFx;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Track Actions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('track-properties-rename'),
                      tooltip: 'Rename $trackName',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onRename,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 48, child: Text('Pan')),
                    const Text('L', style: TextStyle(fontSize: 10)),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: onPanReset,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            trackShape: const _BipolarPanTrackShape(),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            showValueIndicator: ShowValueIndicator.never,
                          ),
                          child: Slider(
                            key: const ValueKey('track-pan-slider'),
                            value: clampTrackPan(pan),
                            min: minimumTrackPan,
                            max: maximumTrackPan,
                            semanticFormatterCallback: formatTrackPanSemantics,
                            onChangeStart: onPanChangeStart,
                            onChanged: onPanChanged,
                            onChangeEnd: onPanChangeEnd,
                          ),
                        ),
                      ),
                    ),
                    const Text('R', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        formatTrackPan(pan),
                        key: const ValueKey('track-pan-value'),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 48, child: Text('Color')),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final preset in trackColorPresets)
                            Tooltip(
                              message: preset.label,
                              child: InkResponse(
                                key: ValueKey(
                                  'track-properties-color-${preset.label.toLowerCase()}',
                                ),
                                radius: 14,
                                onTap: () => onColorSelected(preset.colorValue),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: preset.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorValue == preset.colorValue
                                          ? colorScheme.onSurface
                                          : colorScheme.outline.withValues(
                                              alpha: 0.65,
                                            ),
                                      width: colorValue == preset.colorValue
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
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const ValueKey('track-properties-fx'),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: onTrackFx,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Track FX'),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const ValueKey('track-properties-duplicate'),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Duplicate Track'),
                  ),
                ),
                const SizedBox(height: 2),
                const Divider(height: 1),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const ValueKey('track-properties-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Track'),
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

class _BipolarPanTrackShape extends SliderTrackShape {
  const _BipolarPanTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final thumbWidth =
        sliderTheme.thumbShape?.getPreferredSize(isEnabled, isDiscrete).width ??
        0;
    return Rect.fromLTWH(
      offset.dx + thumbWidth / 2,
      offset.dy + (parentBox.size.height - trackHeight) / 2,
      parentBox.size.width - thumbWidth,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(trackRect.height / 2);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = sliderTheme.inactiveTrackColor!,
    );
    final centerX = trackRect.center.dx;
    final activeRect = Rect.fromLTRB(
      math.min(centerX, thumbCenter.dx),
      trackRect.top,
      math.max(centerX, thumbCenter.dx),
      trackRect.bottom,
    );
    if (activeRect.width > 0) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, radius),
        Paint()..color = sliderTheme.activeTrackColor!,
      );
    }
    context.canvas.drawLine(
      Offset(centerX, trackRect.top - 3),
      Offset(centerX, trackRect.bottom + 3),
      Paint()
        ..color = sliderTheme.thumbColor!.withValues(alpha: 0.72)
        ..strokeWidth = 1,
    );
  }
}
