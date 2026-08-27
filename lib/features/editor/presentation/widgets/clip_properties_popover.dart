import 'package:flutter/material.dart';

import '../../domain/audio_clip.dart';
import '../editor_shortcut_policy.dart';

class ClipPropertiesPopover extends StatelessWidget {
  const ClipPropertiesPopover({
    super.key,
    required this.clip,
    required this.onGainChangeStart,
    required this.onGainChanged,
    required this.onGainChangeEnd,
    required this.onGainReset,
    required this.onFadeInChangeStart,
    required this.onFadeInChanged,
    required this.onFadeInChangeEnd,
    required this.onFadeInReset,
    required this.onFadeOutChangeStart,
    required this.onFadeOutChanged,
    required this.onFadeOutChangeEnd,
    required this.onFadeOutReset,
  });

  final AudioClip clip;
  final ValueChanged<double> onGainChangeStart;
  final ValueChanged<double> onGainChanged;
  final ValueChanged<double> onGainChangeEnd;
  final VoidCallback onGainReset;
  final ValueChanged<double> onFadeInChangeStart;
  final ValueChanged<double> onFadeInChanged;
  final ValueChanged<double> onFadeInChangeEnd;
  final VoidCallback onFadeInReset;
  final ValueChanged<double> onFadeOutChangeStart;
  final ValueChanged<double> onFadeOutChanged;
  final ValueChanged<double> onFadeOutChangeEnd;
  final VoidCallback onFadeOutReset;

  @override
  Widget build(BuildContext context) {
    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 294,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clip Properties',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _GainSliderRow(
                  valueKey: const ValueKey('clip-gain-slider'),
                  valueDb: clip.gainDb,
                  onChangeStart: onGainChangeStart,
                  onChanged: onGainChanged,
                  onChangeEnd: onGainChangeEnd,
                  onReset: onGainReset,
                ),
                const SizedBox(height: 5),
                _FadeSliderRow(
                  valueKey: const ValueKey('clip-fade-in-slider'),
                  label: 'Fade In',
                  valueSeconds: clip.fadeInDurationSeconds,
                  maximumSeconds:
                      clip.clipDurationSeconds - clip.fadeOutDurationSeconds,
                  onChangeStart: onFadeInChangeStart,
                  onChanged: onFadeInChanged,
                  onChangeEnd: onFadeInChangeEnd,
                  onReset: onFadeInReset,
                ),
                const SizedBox(height: 5),
                _FadeSliderRow(
                  valueKey: const ValueKey('clip-fade-out-slider'),
                  label: 'Fade Out',
                  valueSeconds: clip.fadeOutDurationSeconds,
                  maximumSeconds:
                      clip.clipDurationSeconds - clip.fadeInDurationSeconds,
                  onChangeStart: onFadeOutChangeStart,
                  onChanged: onFadeOutChanged,
                  onChangeEnd: onFadeOutChangeEnd,
                  onReset: onFadeOutReset,
                ),
                const SizedBox(height: 3),
                Text(
                  'Double-click a clip to reopen',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _GainSliderRow extends StatelessWidget {
  const _GainSliderRow({
    required this.valueKey,
    required this.valueDb,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final Key valueKey;
  final double valueDb;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final displayValue = _formatGainDb(valueDb);
    return Row(
      children: [
        const SizedBox(width: 58, child: Text('Gain')),
        Expanded(
          child: Tooltip(
            message: '$displayValue\nDouble-click to reset',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: onReset,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  key: valueKey,
                  value: clampClipGainDb(valueDb),
                  min: minimumClipGainDb,
                  max: maximumClipGainDb,
                  divisions: 360,
                  semanticFormatterCallback: (value) => _formatGainDb(value),
                  onChangeStart: onChangeStart,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatGainDb(double valueDb) {
  final clamped = clampClipGainDb(valueDb);
  final prefix = clamped > 0 ? '+' : '';
  return '$prefix${clamped.toStringAsFixed(1)} dB';
}

class _FadeSliderRow extends StatelessWidget {
  const _FadeSliderRow({
    required this.valueKey,
    required this.label,
    required this.valueSeconds,
    required this.maximumSeconds,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final Key valueKey;
  final String label;
  final double valueSeconds;
  final double maximumSeconds;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final enabled = maximumSeconds > 0;
    final sliderMaximum = enabled ? maximumSeconds : 1.0;
    final sliderValue = enabled
        ? valueSeconds.clamp(0.0, maximumSeconds).toDouble()
        : 0.0;
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label)),
        Expanded(
          child: Tooltip(
            message:
                '${valueSeconds.toStringAsFixed(2)} s\nDouble-click to reset',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: onReset,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  key: valueKey,
                  value: sliderValue,
                  min: 0,
                  max: sliderMaximum,
                  semanticFormatterCallback: (value) =>
                      '${value.toStringAsFixed(2)} seconds',
                  onChangeStart: enabled ? onChangeStart : null,
                  onChanged: enabled ? onChanged : null,
                  onChangeEnd: enabled ? onChangeEnd : null,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${valueSeconds.toStringAsFixed(2)} s',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
