import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'daw_interaction_hint.dart';

class MixerVerticalFader extends StatefulWidget {
  const MixerVerticalFader({
    super.key,
    required this.valueDb,
    required this.minimumDb,
    required this.maximumDb,
    required this.unityDb,
    required this.semanticLabel,
    required this.valueFormatter,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
    this.accent = const Color(0xFF8D73FF),
  });

  final double valueDb;
  final double minimumDb;
  final double maximumDb;
  final double unityDb;
  final String semanticLabel;
  final String Function(double value) valueFormatter;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;
  final Color accent;

  @override
  State<MixerVerticalFader> createState() => _MixerVerticalFaderState();
}

class _MixerVerticalFaderState extends State<MixerVerticalFader> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'mixer-fader');
  late double _displayDb;
  bool _dragging = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _displayDb = _clamp(widget.valueDb);
  }

  @override
  void didUpdateWidget(covariant MixerVerticalFader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.valueDb != widget.valueDb) {
      _displayDb = _clamp(widget.valueDb);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueLabel = widget.valueFormatter(_displayDb);
    return DawInteractionHint(
      data: DawInteractionHintData(
        title: 'Drag to adjust volume',
        detail: 'Shift+drag · Fine control   Double-click · Reset to 0 dB',
        semanticsLabel: '${widget.semanticLabel}, $valueLabel',
      ),
      child: Semantics(
        slider: true,
        label: widget.semanticLabel,
        value: valueLabel,
        increasedValue: widget.valueFormatter(_clamp(_displayDb + 1)),
        decreasedValue: widget.valueFormatter(_clamp(_displayDb - 1)),
        onIncrease: () => _nudge(1),
        onDecrease: () => _nudge(-1),
        child: FocusableActionDetector(
          focusNode: _focusNode,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowUp): _FaderNudgeIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowRight): _FaderNudgeIntent(
              1,
            ),
            SingleActivator(LogicalKeyboardKey.arrowDown): _FaderNudgeIntent(
              -1,
            ),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _FaderNudgeIntent(
              -1,
            ),
          },
          actions: {
            _FaderNudgeIntent: CallbackAction<_FaderNudgeIntent>(
              onInvoke: (intent) {
                final step = HardwareKeyboard.instance.isShiftPressed ? .1 : 1;
                _nudge(intent.direction * step);
                return null;
              },
            ),
          },
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
          mouseCursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            key: widget.key == null
                ? const ValueKey('mixer-vertical-fader')
                : null,
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _focusNode.requestFocus(),
            onDoubleTap: _reset,
            onVerticalDragStart: (_) {
              _dragging = true;
              _displayDb = _clamp(widget.valueDb);
              widget.onChangeStart();
              setState(() {});
            },
            onVerticalDragUpdate: (details) {
              final fine = HardwareKeyboard.instance.isShiftPressed;
              final normalized = _dbToFader(_displayDb);
              final height = math.max(80.0, context.size?.height ?? 160.0);
              final nextNormalized =
                  (normalized - details.delta.dy / height / (fine ? 5 : 1))
                      .clamp(0.0, 1.0);
              final next = _clamp(_faderToDb(nextNormalized));
              if (next == _displayDb) return;
              _displayDb = next;
              widget.onChanged(next);
              setState(() {});
            },
            onVerticalDragEnd: (_) => _finishDrag(),
            onVerticalDragCancel: _finishDrag,
            child: CustomPaint(
              painter: _MixerFaderPainter(
                valueDb: _displayDb,
                minimumDb: widget.minimumDb,
                accent: widget.accent,
                active: _dragging,
                hovered: _hovered,
                focused: _focused,
                colors: colors,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  void _finishDrag() {
    if (!_dragging) return;
    _dragging = false;
    widget.onChangeEnd(_displayDb);
    if (mounted) setState(() {});
  }

  void _reset() {
    _dragging = false;
    _displayDb = _clamp(widget.unityDb);
    widget.onReset();
    setState(() {});
  }

  void _nudge(double amount) {
    final next = _clamp(_displayDb + amount);
    if (next == _displayDb) return;
    widget.onChangeStart();
    _displayDb = next;
    widget.onChanged(next);
    widget.onChangeEnd(next);
    setState(() {});
  }

  double _clamp(double value) =>
      value.clamp(widget.minimumDb, widget.maximumDb).toDouble();
}

class _FaderNudgeIntent extends Intent {
  const _FaderNudgeIntent(this.direction);

  final double direction;
}

class _MixerFaderPainter extends CustomPainter {
  const _MixerFaderPainter({
    required this.valueDb,
    required this.minimumDb,
    required this.accent,
    required this.active,
    required this.hovered,
    required this.focused,
    required this.colors,
  });

  final double valueDb;
  final double minimumDb;
  final Color accent;
  final bool active;
  final bool hovered;
  final bool focused;
  final ColorScheme colors;

  static const _marks = <(double, String)>[
    (6, '+6'),
    (0, '0'),
    (-6, '-6'),
    (-12, '-12'),
    (-24, '-24'),
    (-48, '-48'),
    (-60, '-∞'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (focused || hovered) {
      final highlight = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        highlight,
        Paint()
          ..color = focused
              ? colors.onSurface.withValues(alpha: .72)
              : colors.onSurface.withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 1.2 : .8,
      );
    }
    const top = 8.0;
    const bottom = 8.0;
    final travel = math.max(1.0, size.height - top - bottom);
    final centerX = size.width * .48;
    final trackRect = Rect.fromLTWH(centerX - 3, top, 6, travel);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF090B0F),
    );
    canvas.drawLine(
      Offset(centerX, top + 2),
      Offset(centerX, size.height - bottom - 2),
      Paint()
        ..color = colors.outlineVariant.withValues(alpha: .62)
        ..strokeWidth = 1,
    );

    for (final mark in _marks) {
      if (mark.$1 < minimumDb) continue;
      final y = top + (1 - _dbToFader(mark.$1)) * travel;
      final unity = mark.$1 == 0;
      canvas.drawLine(
        Offset(centerX - (unity ? 9 : 7), y),
        Offset(centerX + (unity ? 9 : 7), y),
        Paint()
          ..color = unity
              ? colors.onSurface.withValues(alpha: .78)
              : colors.outline.withValues(alpha: .58)
          ..strokeWidth = unity ? 1.2 : .8,
      );
      _paintText(
        canvas,
        mark.$2,
        Offset(centerX + 12, y - 4),
        color: unity ? colors.onSurface : colors.onSurfaceVariant,
      );
    }

    final y = top + (1 - _dbToFader(valueDb)) * travel;
    final capRect = Rect.fromCenter(
      center: Offset(centerX, y),
      width: 24,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [accent.withValues(alpha: .95), accent.withValues(alpha: .52)]
              : const [Color(0xFF636A74), Color(0xFF292E35)],
        ).createShader(capRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(2)),
      Paint()
        ..color = active ? accent : const Color(0xFF080A0D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(capRect.left + 4, y),
      Offset(capRect.right - 4, y),
      Paint()
        ..color = Colors.white.withValues(alpha: .78)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MixerFaderPainter oldDelegate) =>
      oldDelegate.valueDb != valueDb ||
      oldDelegate.accent != accent ||
      oldDelegate.active != active ||
      oldDelegate.hovered != hovered ||
      oldDelegate.focused != focused ||
      oldDelegate.colors != colors;
}

// A musical fader taper: more travel is reserved around unity and the normal
// mixing range, while the lowest levels are compressed toward silence.
const _faderPoints = <(double, double)>[
  (-60, 0),
  (-48, .12),
  (-24, .32),
  (-12, .5),
  (-6, .64),
  (0, .8),
  (6, 1),
];

double _dbToFader(double db) {
  final value = db.clamp(_faderPoints.first.$1, _faderPoints.last.$1);
  for (var index = 1; index < _faderPoints.length; index++) {
    final low = _faderPoints[index - 1];
    final high = _faderPoints[index];
    if (value <= high.$1) {
      final fraction = (value - low.$1) / (high.$1 - low.$1);
      return low.$2 + (high.$2 - low.$2) * fraction;
    }
  }
  return 1;
}

double _faderToDb(double normalized) {
  final value = normalized.clamp(0.0, 1.0);
  for (var index = 1; index < _faderPoints.length; index++) {
    final low = _faderPoints[index - 1];
    final high = _faderPoints[index];
    if (value <= high.$2) {
      final fraction = (value - low.$2) / (high.$2 - low.$2);
      return low.$1 + (high.$1 - low.$1) * fraction;
    }
  }
  return _faderPoints.last.$1;
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 7,
        fontWeight: FontWeight.w600,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}
