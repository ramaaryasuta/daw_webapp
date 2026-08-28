import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/daw_track.dart';
import '../../domain/track_filter_fx.dart';
import '../editor_shortcut_policy.dart';

class TrackFilterFxRack extends ConsumerStatefulWidget {
  const TrackFilterFxRack({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<TrackFilterFxRack> createState() => _TrackFilterFxRackState();
}

class _TrackFilterFxRackState extends ConsumerState<TrackFilterFxRack> {
  TrackFilterFx? _preview;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      editorControllerProvider.select(
        (state) => state.tracks
            .where((track) => track.id == widget.trackId)
            .firstOrNull,
      ),
    );
    if (track == null) {
      return const SizedBox.shrink();
    }
    final filter = _preview ?? track.filterFx;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = Color(track.colorValue);

    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 372,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RackHeader(
                  trackName: track.name,
                  enabled: filter.enabled,
                  accent: accent,
                  onToggle: () => ref
                      .read(editorControllerProvider.notifier)
                      .toggleFilterFx(widget.trackId),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'FREQUENCY RESPONSE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.15,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 126,
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomPaint(
                            key: const ValueKey('track-filter-response'),
                            painter: _FilterResponsePainter(
                              filter: filter,
                              accent: accent,
                              gridColor: colorScheme.outlineVariant,
                              labelColor: colorScheme.onSurfaceVariant,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FilterModulePanel(
                          title: 'HIGH PASS',
                          enabled: filter.highPass.enabled,
                          globallyEnabled: filter.enabled,
                          accent: accent,
                          frequencyHz: filter.highPass.frequencyHz,
                          q: filter.highPass.q,
                          frequencyParameter:
                              TrackFilterParameter.highPassFrequency,
                          qParameter: TrackFilterParameter.highPassQ,
                          onToggle: () => ref
                              .read(editorControllerProvider.notifier)
                              .toggleTrackFilterModule(
                                widget.trackId,
                                highPass: true,
                              ),
                          onPreview: (parameter, value) =>
                              _previewParameter(track, parameter, value),
                          onCommit: (parameter, value) =>
                              _commitParameter(parameter, value),
                          onBegin: _beginParameter,
                          onReset: _resetParameter,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 146,
                        color: colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: _FilterModulePanel(
                          title: 'LOW PASS',
                          enabled: filter.lowPass.enabled,
                          globallyEnabled: filter.enabled,
                          accent: accent,
                          frequencyHz: filter.lowPass.frequencyHz,
                          q: filter.lowPass.q,
                          frequencyParameter:
                              TrackFilterParameter.lowPassFrequency,
                          qParameter: TrackFilterParameter.lowPassQ,
                          onToggle: () => ref
                              .read(editorControllerProvider.notifier)
                              .toggleTrackFilterModule(
                                widget.trackId,
                                highPass: false,
                              ),
                          onPreview: (parameter, value) =>
                              _previewParameter(track, parameter, value),
                          onCommit: (parameter, value) =>
                              _commitParameter(parameter, value),
                          onBegin: _beginParameter,
                          onReset: _resetParameter,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _beginParameter(TrackFilterParameter parameter) {
    ref
        .read(editorControllerProvider.notifier)
        .beginTrackFilterChange(widget.trackId, parameter);
  }

  void _previewParameter(
    DawTrack track,
    TrackFilterParameter parameter,
    double value,
  ) {
    final base = _preview ?? track.filterFx;
    setState(() => _preview = _withParameter(base, parameter, value));
    ref
        .read(editorControllerProvider.notifier)
        .previewTrackFilterChange(widget.trackId, parameter, value);
  }

  void _commitParameter(TrackFilterParameter parameter, double value) {
    ref
        .read(editorControllerProvider.notifier)
        .commitTrackFilterChange(widget.trackId, parameter, value);
    if (mounted) {
      setState(() => _preview = null);
    }
  }

  void _resetParameter(TrackFilterParameter parameter) {
    ref
        .read(editorControllerProvider.notifier)
        .resetTrackFilterParameter(widget.trackId, parameter);
    setState(() => _preview = null);
  }
}

TrackFilterFx _withParameter(
  TrackFilterFx filter,
  TrackFilterParameter parameter,
  double value,
) {
  return switch (parameter) {
    TrackFilterParameter.highPassFrequency => filter.copyWith(
      highPass: filter.highPass.copyWith(frequencyHz: value),
    ),
    TrackFilterParameter.highPassQ => filter.copyWith(
      highPass: filter.highPass.copyWith(q: value),
    ),
    TrackFilterParameter.lowPassFrequency => filter.copyWith(
      lowPass: filter.lowPass.copyWith(frequencyHz: value),
    ),
    TrackFilterParameter.lowPassQ => filter.copyWith(
      lowPass: filter.lowPass.copyWith(q: value),
    ),
  };
}

class _RackHeader extends StatelessWidget {
  const _RackHeader({
    required this.trackName,
    required this.enabled,
    required this.accent,
    required this.onToggle,
  });

  final String trackName;
  final bool enabled;
  final Color accent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: enabled ? accent : colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FILTER',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Track: $trackName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _CompactPowerButton(
            key: const ValueKey('filter-fx-global-toggle'),
            label: enabled ? 'ON' : 'OFF',
            enabled: enabled,
            accent: accent,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _FilterModulePanel extends StatelessWidget {
  const _FilterModulePanel({
    required this.title,
    required this.enabled,
    required this.globallyEnabled,
    required this.accent,
    required this.frequencyHz,
    required this.q,
    required this.frequencyParameter,
    required this.qParameter,
    required this.onToggle,
    required this.onBegin,
    required this.onPreview,
    required this.onCommit,
    required this.onReset,
  });

  final String title;
  final bool enabled;
  final bool globallyEnabled;
  final Color accent;
  final double frequencyHz;
  final double q;
  final TrackFilterParameter frequencyParameter;
  final TrackFilterParameter qParameter;
  final VoidCallback onToggle;
  final ValueChanged<TrackFilterParameter> onBegin;
  final void Function(TrackFilterParameter, double) onPreview;
  final void Function(TrackFilterParameter, double) onCommit;
  final ValueChanged<TrackFilterParameter> onReset;

  @override
  Widget build(BuildContext context) {
    final active = enabled && globallyEnabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: active ? 1 : 0.58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _CompactPowerButton(
                  key: ValueKey('${title.toLowerCase()}-toggle'),
                  label: enabled ? 'ON' : 'OFF',
                  enabled: enabled,
                  accent: accent,
                  onPressed: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RotaryKnob(
                  key: ValueKey('$frequencyParameter-knob'),
                  label: 'CUTOFF',
                  value: frequencyHz,
                  minimum: minimumFilterFrequencyHz,
                  maximum: maximumFilterFrequencyHz,
                  logarithmic: true,
                  valueLabel: formatFilterFrequency(frequencyHz),
                  active: active,
                  accent: accent,
                  onChangeStart: () => onBegin(frequencyParameter),
                  onChanged: (value) => onPreview(frequencyParameter, value),
                  onChangeEnd: (value) => onCommit(frequencyParameter, value),
                  onReset: () => onReset(frequencyParameter),
                ),
                _RotaryKnob(
                  key: ValueKey('$qParameter-knob'),
                  label: 'RES',
                  value: q,
                  minimum: minimumFilterQ,
                  maximum: maximumFilterQ,
                  logarithmic: false,
                  valueLabel: 'Q ${q.toStringAsFixed(2)}',
                  active: active,
                  accent: accent,
                  onChangeStart: () => onBegin(qParameter),
                  onChanged: (value) => onPreview(qParameter, value),
                  onChangeEnd: (value) => onCommit(qParameter, value),
                  onReset: () => onReset(qParameter),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPowerButton extends StatelessWidget {
  const _CompactPowerButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: enabled ? 'Bypass' : 'Enable',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 24,
          constraints: const BoxConstraints(minWidth: 42),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.85) : scheme.outline,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: enabled ? accent : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotaryKnob extends StatefulWidget {
  const _RotaryKnob({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.logarithmic,
    required this.valueLabel,
    required this.active,
    required this.accent,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final bool logarithmic;
  final String valueLabel;
  final bool active;
  final Color accent;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  State<_RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<_RotaryKnob> {
  late double _normalized;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _normalized = _normalize(widget.value);
  }

  @override
  void didUpdateWidget(covariant _RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) {
      _normalized = _normalize(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${widget.label} ${widget.valueLabel}',
      slider: true,
      value: widget.valueLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onReset,
          onVerticalDragStart: (_) {
            _dragging = true;
            _normalized = _normalize(widget.value);
            widget.onChangeStart();
          },
          onVerticalDragUpdate: (details) {
            final fine = HardwareKeyboard.instance.logicalKeysPressed.any(
              (key) =>
                  key == LogicalKeyboardKey.shiftLeft ||
                  key == LogicalKeyboardKey.shiftRight,
            );
            _normalized = (_normalized - details.delta.dy / (fine ? 720 : 150))
                .clamp(0.0, 1.0);
            widget.onChanged(_denormalize(_normalized));
          },
          onVerticalDragEnd: (_) {
            _dragging = false;
            widget.onChangeEnd(_denormalize(_normalized));
          },
          onVerticalDragCancel: () {
            _dragging = false;
            widget.onChangeEnd(_denormalize(_normalized));
          },
          child: SizedBox(
            width: 68,
            child: Column(
              children: [
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                CustomPaint(
                  painter: _KnobPainter(
                    normalized: _normalized,
                    active: widget.active,
                    accent: widget.accent,
                    bodyColor: scheme.surfaceContainerHighest,
                    inactiveColor: scheme.outline,
                  ),
                  child: const SizedBox.square(dimension: 48),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.valueLabel,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _normalize(double value) {
    if (widget.logarithmic) {
      return math.log(value / widget.minimum) /
          math.log(widget.maximum / widget.minimum);
    }
    return (value - widget.minimum) / (widget.maximum - widget.minimum);
  }

  double _denormalize(double normalized) {
    if (widget.logarithmic) {
      return widget.minimum *
          math.pow(widget.maximum / widget.minimum, normalized).toDouble();
    }
    return widget.minimum + normalized * (widget.maximum - widget.minimum);
  }
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter({
    required this.normalized,
    required this.active,
    required this.accent,
    required this.bodyColor,
    required this.inactiveColor,
  });

  final double normalized;
  final bool active;
  final Color accent;
  final Color bodyColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final arcRect = Rect.fromCircle(center: center, radius: 21);
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = inactiveColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      arcRect,
      start,
      sweep * normalized,
      false,
      Paint()
        ..color = active ? accent : inactiveColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(
      center,
      16.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.32),
          colors: [Color(0xFF50545C), Color(0xFF1A1C20)],
        ).createShader(Rect.fromCircle(center: center, radius: 17)),
    );
    canvas.drawCircle(
      center,
      16.5,
      Paint()
        ..color = const Color(0xFF060708)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final angle = start + sweep * normalized;
    canvas.drawLine(
      center + Offset(math.cos(angle), math.sin(angle)) * 6,
      center + Offset(math.cos(angle), math.sin(angle)) * 13,
      Paint()
        ..color = active ? accent : const Color(0xFF9A9DA3)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.normalized != normalized ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent ||
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.inactiveColor != inactiveColor;
}

class _FilterResponsePainter extends CustomPainter {
  const _FilterResponsePainter({
    required this.filter,
    required this.accent,
    required this.gridColor,
    required this.labelColor,
  });

  final TrackFilterFx filter;
  final Color accent;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 22.0;
    final graph = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (final db in const [-24.0, -12.0, 0.0]) {
      final y = _dbY(db, graph);
      canvas.drawLine(Offset(graph.left, y), Offset(graph.right, y), gridPaint);
    }
    for (final frequency in const [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
      final x = _frequencyX(frequency, graph);
      canvas.drawLine(Offset(x, graph.top), Offset(x, graph.bottom), gridPaint);
      final label = switch (frequency) {
        20 => '20',
        100 => '100',
        1000 => '1k',
        10000 => '10k',
        _ => '20k',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          graph.bottom + 5,
        ),
      );
    }

    final active =
        filter.enabled && (filter.highPass.enabled || filter.lowPass.enabled);
    final path = Path();
    const pointCount = 180;
    for (var index = 0; index < pointCount; index++) {
      final ratio = index / (pointCount - 1);
      final frequency =
          minimumFilterFrequencyHz *
          math.pow(maximumFilterFrequencyHz / minimumFilterFrequencyHz, ratio);
      var magnitude = 1.0;
      if (filter.enabled && filter.highPass.enabled) {
        magnitude *= _biquadMagnitude(
          frequency: frequency.toDouble(),
          cutoff: filter.highPass.frequencyHz,
          q: filter.highPass.q,
          highPass: true,
        );
      }
      if (filter.enabled && filter.lowPass.enabled) {
        magnitude *= _biquadMagnitude(
          frequency: frequency.toDouble(),
          cutoff: filter.lowPass.frequencyHz,
          q: filter.lowPass.q,
          highPass: false,
        );
      }
      final db = 20 * math.log(math.max(magnitude, 0.000001)) / math.ln10;
      final point = Offset(
        graph.left + graph.width * ratio,
        _dbY(db.clamp(-36.0, 12.0), graph),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = active ? accent : labelColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _frequencyX(double frequency, Rect graph) {
    final ratio =
        math.log(frequency / minimumFilterFrequencyHz) /
        math.log(maximumFilterFrequencyHz / minimumFilterFrequencyHz);
    return graph.left + graph.width * ratio;
  }

  double _dbY(double db, Rect graph) =>
      graph.top + graph.height * ((12 - db) / 48);

  double _biquadMagnitude({
    required double frequency,
    required double cutoff,
    required double q,
    required bool highPass,
  }) {
    const sampleRate = 48000.0;
    final omega0 = 2 * math.pi * cutoff / sampleRate;
    final cosine0 = math.cos(omega0);
    final alpha = math.sin(omega0) / (2 * q);
    final a0 = 1 + alpha;
    final a1 = -2 * cosine0 / a0;
    final a2 = (1 - alpha) / a0;
    final scale = highPass ? 1 + cosine0 : 1 - cosine0;
    final b0 = scale / 2 / a0;
    final b1 = (highPass ? -scale : scale) / a0;
    final b2 = b0;
    final omega = 2 * math.pi * frequency / sampleRate;
    final cosine = math.cos(omega);
    final sine = math.sin(omega);
    final cosine2 = math.cos(2 * omega);
    final sine2 = math.sin(2 * omega);
    final numeratorReal = b0 + b1 * cosine + b2 * cosine2;
    final numeratorImaginary = -b1 * sine - b2 * sine2;
    final denominatorReal = 1 + a1 * cosine + a2 * cosine2;
    final denominatorImaginary = -a1 * sine - a2 * sine2;
    return math.sqrt(
      (numeratorReal * numeratorReal +
              numeratorImaginary * numeratorImaginary) /
          (denominatorReal * denominatorReal +
              denominatorImaginary * denominatorImaginary),
    );
  }

  @override
  bool shouldRepaint(covariant _FilterResponsePainter oldDelegate) =>
      oldDelegate.filter != filter ||
      oldDelegate.accent != accent ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
