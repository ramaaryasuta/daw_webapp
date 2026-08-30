import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'daw_interaction_hint.dart';

class DawRotaryKnob extends StatefulWidget {
  const DawRotaryKnob({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.logarithmic,
    required this.valueLabel,
    required this.valueFormatter,
    required this.active,
    required this.accent,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
    this.hint,
  });

  final String label;
  final String semanticLabel;
  final double value;
  final double minimum;
  final double maximum;
  final bool logarithmic;
  final String valueLabel;
  final String Function(double value) valueFormatter;
  final bool active;
  final Color accent;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;
  final DawInteractionHintData? hint;

  @override
  State<DawRotaryKnob> createState() => _DawRotaryKnobState();
}

class _DawRotaryKnobState extends State<DawRotaryKnob> {
  late double _normalized;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _normalized = _normalize(widget.value);
  }

  @override
  void didUpdateWidget(covariant DawRotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) {
      _normalized = _normalize(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DawInteractionHint(
      data: widget.hint ?? DawInteractionHints.rotaryKnob,
      child: Semantics(
        label: widget.semanticLabel,
        slider: true,
        value: widget.valueLabel,
        increasedValue: _adjustedValueLabel(.02),
        decreasedValue: _adjustedValueLabel(-.02),
        onIncrease: () => _adjustBy(.02),
        onDecrease: () => _adjustBy(-.02),
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
              _normalized =
                  (_normalized - details.delta.dy / (fine ? 720 : 150)).clamp(
                    0.0,
                    1.0,
                  );
              widget.onChanged(_denormalize(_normalized));
              setState(() {});
            },
            onVerticalDragEnd: (_) => _finishDrag(),
            onVerticalDragCancel: _finishDrag,
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
                    painter: _DawKnobPainter(
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
      ),
    );
  }

  void _finishDrag() {
    if (!_dragging) return;
    _dragging = false;
    widget.onChangeEnd(_denormalize(_normalized));
    if (mounted) setState(() {});
  }

  void _adjustBy(double delta) {
    _normalized = (_normalize(widget.value) + delta).clamp(0.0, 1.0);
    final value = _denormalize(_normalized);
    widget.onChangeStart();
    widget.onChanged(value);
    widget.onChangeEnd(value);
    if (mounted) setState(() {});
  }

  String _adjustedValueLabel(double delta) {
    final normalized = (_normalize(widget.value) + delta).clamp(0.0, 1.0);
    return widget.valueFormatter(_denormalize(normalized));
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

class _DawKnobPainter extends CustomPainter {
  const _DawKnobPainter({
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
  bool shouldRepaint(covariant _DawKnobPainter oldDelegate) =>
      oldDelegate.normalized != normalized ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent ||
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
