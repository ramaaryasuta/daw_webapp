import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/track_mixer.dart';
import '../controllers/audio_meter_controller.dart';
import 'audio_level_meter.dart';

class MasterStrip extends StatefulWidget {
  const MasterStrip({
    super.key,
    required this.volumeDb,
    required this.meterController,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final double volumeDb;
  final AudioMeterController meterController;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  State<MasterStrip> createState() => _MasterStripState();
}

class _MasterStripState extends State<MasterStrip> {
  late double _displayDb;
  bool _dragging = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _displayDb = clampMasterVolumeDb(widget.volumeDb);
  }

  @override
  void didUpdateWidget(covariant MasterStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.volumeDb != oldWidget.volumeDb) {
      _displayDb = clampMasterVolumeDb(widget.volumeDb);
    }
  }

  void _startDrag(DragStartDetails details) {
    _dragging = true;
    widget.onChangeStart();
    setState(() {});
  }

  void _updateDrag(DragUpdateDetails details) {
    final sensitivity = HardwareKeyboard.instance.isShiftPressed ? 0.06 : 0.24;
    final next = clampMasterVolumeDb(
      _displayDb - details.delta.dy * sensitivity,
    );
    if (next == _displayDb) {
      return;
    }
    setState(() => _displayDb = next);
    widget.onChanged(next);
  }

  void _finishDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.onChangeEnd(_displayDb);
  }

  void _reset() {
    if (_displayDb == unityMasterVolumeDb &&
        widget.volumeDb == unityMasterVolumeDb) {
      return;
    }
    setState(() {
      _dragging = false;
      _displayDb = unityMasterVolumeDb;
    });
    widget.onReset();
  }

  void _nudge(double deltaDb) {
    final next = clampMasterVolumeDb(_displayDb + deltaDb);
    if (next == _displayDb) {
      return;
    }
    widget.onChangeStart();
    setState(() => _displayDb = next);
    widget.onChanged(next);
    widget.onChangeEnd(next);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showFullLabel = constraints.maxWidth >= 205;
        final showValueBlock = constraints.maxWidth >= 150;
        return AnimatedContainer(
          key: const ValueKey('master-strip'),
          duration: const Duration(milliseconds: 100),
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _dragging
                  ? colorScheme.primary.withValues(alpha: 0.65)
                  : colorScheme.outlineVariant,
            ),
            boxShadow: _dragging
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Tooltip(
                message:
                    '${formatMasterVolumeDb(_displayDb)}\n'
                    'Drag vertically; hold Shift for fine control\n'
                    'Double-click to reset',
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: Semantics(
                    label: 'Master volume',
                    value: formatMasterVolumeDb(_displayDb),
                    increasedValue: formatMasterVolumeDb(_displayDb + 1),
                    decreasedValue: formatMasterVolumeDb(_displayDb - 1),
                    onIncrease: () => _nudge(1),
                    onDecrease: () => _nudge(-1),
                    child: GestureDetector(
                      key: const ValueKey('master-volume-knob'),
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _reset,
                      onVerticalDragStart: _startDrag,
                      onVerticalDragUpdate: _updateDrag,
                      onVerticalDragEnd: (_) => _finishDrag(),
                      onVerticalDragCancel: _finishDrag,
                      child: SizedBox.square(
                        dimension: 40,
                        child: CustomPaint(
                          painter: _MasterKnobPainter(
                            volumeDb: _displayDb,
                            active: _dragging || _hovered,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showValueBlock) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: showFullLabel ? 58 : 43,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showFullLabel ? 'MASTER' : 'MST',
                        maxLines: 1,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: showFullLabel ? 8 : 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatMasterVolumeDb(_displayDb),
                          key: const ValueKey('master-volume-value'),
                          maxLines: 1,
                          style: TextStyle(
                            color: _displayDb > 0
                                ? const Color(0xFFF1C84B)
                                : colorScheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Expanded(
                child: MasterStereoMeter(
                  controller: widget.meterController,
                  width: double.infinity,
                  height: 40,
                  showLabel: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MasterKnobPainter extends CustomPainter {
  const _MasterKnobPainter({
    required this.volumeDb,
    required this.active,
    required this.colorScheme,
  });

  final double volumeDb;
  final bool active;
  final ColorScheme colorScheme;

  static const _startAngle = math.pi * 0.75;
  static const _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final arcRect = Rect.fromCircle(center: center, radius: 16);
    final fraction =
        (clampMasterVolumeDb(volumeDb) - minimumMasterVolumeDb) /
        (maximumMasterVolumeDb - minimumMasterVolumeDb);
    final unityFraction =
        (unityMasterVolumeDb - minimumMasterVolumeDb) /
        (maximumMasterVolumeDb - minimumMasterVolumeDb);

    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = colorScheme.onSurface.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepAngle * fraction,
      false,
      Paint()
        ..color = active
            ? colorScheme.primary
            : colorScheme.primary.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final unityAngle = _startAngle + _sweepAngle * unityFraction;
    final unityOuter =
        center + Offset(math.cos(unityAngle), math.sin(unityAngle)) * 20;
    final unityInner =
        center + Offset(math.cos(unityAngle), math.sin(unityAngle)) * 17;
    canvas.drawLine(
      unityInner,
      unityOuter,
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(center, 12.5, Paint()..color = const Color(0xFF171B21));
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: [Color(0xFF444B55), Color(0xFF1C2026)],
        ).createShader(Rect.fromCircle(center: center, radius: 12)),
    );

    final angle = _startAngle + _sweepAngle * fraction;
    canvas.drawLine(
      center + Offset(math.cos(angle), math.sin(angle)) * 3,
      center + Offset(math.cos(angle), math.sin(angle)) * 10,
      Paint()
        ..color = colorScheme.onSurface
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MasterKnobPainter oldDelegate) {
    return oldDelegate.volumeDb != volumeDb ||
        oldDelegate.active != active ||
        oldDelegate.colorScheme != colorScheme;
  }
}
