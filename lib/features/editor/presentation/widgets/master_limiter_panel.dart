import 'package:flutter/material.dart';

import '../../domain/master_limiter.dart';
import '../controllers/audio_meter_controller.dart';
import 'daw_interaction_hint.dart';
import 'daw_rotary_knob.dart';

class MasterLimiterPanel extends StatefulWidget {
  const MasterLimiterPanel({
    super.key,
    required this.settings,
    required this.meterController,
    required this.onToggle,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onParameterReset,
    required this.onReset,
  });

  final MasterLimiterSettings settings;
  final AudioMeterController meterController;
  final VoidCallback onToggle;
  final ValueChanged<MasterLimiterParameter> onChangeStart;
  final void Function(MasterLimiterParameter parameter, double value) onChanged;
  final void Function(MasterLimiterParameter parameter, double value)
  onChangeEnd;
  final ValueChanged<MasterLimiterParameter> onParameterReset;
  final VoidCallback onReset;

  @override
  State<MasterLimiterPanel> createState() => _MasterLimiterPanelState();
}

class _MasterLimiterPanelState extends State<MasterLimiterPanel> {
  late MasterLimiterSettings _display;
  MasterLimiterParameter? _editing;

  @override
  void initState() {
    super.initState();
    _display = widget.settings.clamped();
  }

  @override
  void didUpdateWidget(covariant MasterLimiterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing == null && oldWidget.settings != widget.settings) {
      _display = widget.settings.clamped();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        label:
            'Master Limiter, ${widget.settings.enabled ? 'enabled' : 'disabled'}',
        child: Container(
          key: const ValueKey('master-limiter-panel'),
          width: 310,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              Colors.black.withValues(alpha: .18),
              colors.surfaceContainerHigh,
            ),
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'MASTER LIMITER',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('master-limiter-reset'),
                    onPressed: widget.onReset,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(42, 26),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    toggled: widget.settings.enabled,
                    label: 'Master Limiter',
                    child: FilterChip(
                      key: const ValueKey('master-limiter-toggle'),
                      label: Text(widget.settings.enabled ? 'ON' : 'OFF'),
                      selected: widget.settings.enabled,
                      onSelected: (_) => widget.onToggle(),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      labelStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _GainReductionMeter(
                controller: widget.meterController,
                active: widget.settings.enabled,
                accent: accent,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .75),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _knob(
                      parameter: MasterLimiterParameter.threshold,
                      label: 'THRESHOLD',
                      semanticLabel: 'Limiter threshold',
                      hint: 'Lower to apply stronger limiting',
                      value: _display.thresholdDb,
                      minimum: minimumMasterLimiterThresholdDb,
                      maximum: maximumMasterLimiterThresholdDb,
                      valueFormatter: formatMasterLimiterDb,
                    ),
                    _divider(colors),
                    _knob(
                      parameter: MasterLimiterParameter.ceiling,
                      label: 'CEILING',
                      semanticLabel: 'Limiter ceiling',
                      hint: 'Sets the final sample-peak limit',
                      value: _display.ceilingDb,
                      minimum: minimumMasterLimiterCeilingDb,
                      maximum: maximumMasterLimiterCeilingDb,
                      valueFormatter: formatMasterLimiterDb,
                    ),
                    _divider(colors),
                    _knob(
                      parameter: MasterLimiterParameter.release,
                      label: 'RELEASE',
                      semanticLabel: 'Limiter release',
                      hint: 'Controls how quickly limiting recovers',
                      value: _display.releaseSeconds,
                      minimum: minimumMasterLimiterReleaseSeconds,
                      maximum: maximumMasterLimiterReleaseSeconds,
                      logarithmic: true,
                      valueFormatter: formatMasterLimiterRelease,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ColorScheme colors) => Container(
    width: 1,
    height: 70,
    color: colors.outlineVariant.withValues(alpha: .55),
  );

  Widget _knob({
    required MasterLimiterParameter parameter,
    required String label,
    required String semanticLabel,
    required String hint,
    required double value,
    required double minimum,
    required double maximum,
    required String Function(double) valueFormatter,
    bool logarithmic = false,
  }) {
    return DawRotaryKnob(
      key: ValueKey('master-limiter-${parameter.name}'),
      label: label,
      semanticLabel: semanticLabel,
      value: value,
      minimum: minimum,
      maximum: maximum,
      logarithmic: logarithmic,
      valueLabel: valueFormatter(value),
      valueFormatter: valueFormatter,
      active: widget.settings.enabled,
      accent: Theme.of(context).colorScheme.primary,
      hint: DawInteractionHintData(
        title: hint,
        detail: DawInteractionHints.rotaryKnob.plainText,
      ),
      onChangeStart: () {
        _editing = parameter;
        widget.onChangeStart(parameter);
      },
      onChanged: (next) {
        setState(() => _display = _withValue(parameter, next));
        widget.onChanged(parameter, next);
      },
      onChangeEnd: (next) {
        setState(() {
          _display = _withValue(parameter, next);
          _editing = null;
        });
        widget.onChangeEnd(parameter, next);
      },
      onReset: () {
        _editing = null;
        widget.onParameterReset(parameter);
      },
    );
  }

  MasterLimiterSettings _withValue(
    MasterLimiterParameter parameter,
    double value,
  ) => switch (parameter) {
    MasterLimiterParameter.threshold => _display.copyWith(thresholdDb: value),
    MasterLimiterParameter.ceiling => _display.copyWith(ceilingDb: value),
    MasterLimiterParameter.release => _display.copyWith(releaseSeconds: value),
  };
}

class _GainReductionMeter extends StatelessWidget {
  const _GainReductionMeter({
    required this.controller,
    required this.active,
    required this.accent,
  });

  final AudioMeterController controller;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final reduction = active
            ? controller.masterLimiterReductionDb.clamp(-24.0, 0.0)
            : 0.0;
        final magnitude = -reduction;
        return DawInteractionHint(
          data: const DawInteractionHintData(
            title: 'Shows how much level the Limiter is reducing',
          ),
          child: Semantics(
            label: 'Gain reduction',
            value: '${magnitude.toStringAsFixed(1)} decibels',
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
              decoration: BoxDecoration(
                color: const Color(0xFF111419),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .7),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'GAIN REDUCTION',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${reduction.toStringAsFixed(1)} dB',
                        key: const ValueKey('master-limiter-gr-value'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      key: const ValueKey('master-limiter-gr-meter'),
                      value: magnitude / 24,
                      minHeight: 7,
                      color: accent,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0', style: TextStyle(fontSize: 7)),
                      Text('-3', style: TextStyle(fontSize: 7)),
                      Text('-6', style: TextStyle(fontSize: 7)),
                      Text('-12', style: TextStyle(fontSize: 7)),
                      Text('-24', style: TextStyle(fontSize: 7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
