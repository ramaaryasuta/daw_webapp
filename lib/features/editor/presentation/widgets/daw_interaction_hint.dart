import 'package:flutter/material.dart';

/// Copy shared by contextual hints so recurring DAW gestures use the same
/// language throughout the editor.
abstract final class DawInteractionHints {
  static const audioClip = DawInteractionHintData(
    title: 'Double-click · Clip Properties',
    detail: 'Drag · Move clip   Ctrl+click · Multi-select',
    semanticsLabel:
        'Audio clip. Double-click for Clip Properties. Drag to move. '
        'Control-click to multi-select.',
  );

  static const trackName = DawInteractionHintData(
    title: 'Double-click to rename track',
  );

  static const trackReorder = DawInteractionHintData(
    title: 'Drag to reorder track',
  );

  static const section = DawInteractionHintData(
    title: 'Double-click · Section Properties',
    detail: 'Drag · Move   Drag edges · Resize',
  );

  static DawInteractionHintData sectionNamed(String name) =>
      DawInteractionHintData(
        title: section.title,
        detail: section.detail,
        semanticsLabel:
            'Section $name. Double-click for Section Properties. Drag to move '
            'or drag the edges to resize.',
      );

  static const marker = DawInteractionHintData(
    title: 'Double-click · Marker Properties',
    detail: 'Drag · Move',
  );

  static DawInteractionHintData markerNamed(String name) =>
      DawInteractionHintData(
        title: marker.title,
        detail: marker.detail,
        semanticsLabel:
            'Marker $name. Double-click for Marker Properties. Drag to move.',
      );

  static const sectionLane = DawInteractionHintData(
    title: 'Drag · Create Section',
    detail: 'Double-click · Add Marker',
    semanticsLabel:
        'Section lane. Drag to create a Section. Double-click to add a Marker.',
  );

  static const rotaryKnob = DawInteractionHintData(
    title: 'Drag vertically · Adjust',
    detail: 'Shift+drag · Fine control   Double-click · Reset',
  );
}

@immutable
class DawInteractionHintData {
  const DawInteractionHintData({
    required this.title,
    this.detail,
    this.semanticsLabel,
  });

  final String title;
  final String? detail;
  final String? semanticsLabel;

  String get plainText => detail == null ? title : '$title\n$detail';
}

/// A delayed, compact tooltip for interactions that have no visible affordance.
///
/// Flutter's tooltip overlay supplies viewport-safe placement and owns overlay
/// cleanup. This wrapper adds the editor's styling, descendant-focus support,
/// and immediate dismissal as soon as a pointer interaction begins.
class DawInteractionHint extends StatefulWidget {
  const DawInteractionHint({
    super.key,
    required this.data,
    required this.child,
    this.enabled = true,
    this.waitDuration = const Duration(milliseconds: 600),
  });

  final DawInteractionHintData data;
  final Widget child;
  final bool enabled;
  final Duration waitDuration;

  @override
  State<DawInteractionHint> createState() => _DawInteractionHintState();
}

class _DawInteractionHintState extends State<DawInteractionHint> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  void _handleFocusChanged(bool hasFocus) {
    if (!widget.enabled) return;
    if (hasFocus) {
      _tooltipKey.currentState?.ensureTooltipVisible();
    } else {
      Tooltip.dismissAllToolTips();
    }
  }

  void _dismiss() {
    Tooltip.dismissAllToolTips();
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final colors = Theme.of(context).colorScheme;
    Widget result = Tooltip(
      key: _tooltipKey,
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: widget.data.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (widget.data.detail case final detail?) ...[
            const TextSpan(text: '\n'),
            TextSpan(
              text: detail,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
      waitDuration: widget.waitDuration,
      exitDuration: Duration.zero,
      showDuration: const Duration(seconds: 6),
      preferBelow: false,
      verticalOffset: 14,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.black.withValues(alpha: .22),
          colors.surfaceContainerHighest,
        ),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      textStyle: TextStyle(color: colors.onSurface, fontSize: 11, height: 1.25),
      excludeFromSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _dismiss(),
        child: widget.child,
      ),
    );
    result = Focus(
      canRequestFocus: false,
      onFocusChange: _handleFocusChanged,
      child: result,
    );
    final semanticsLabel = widget.data.semanticsLabel;
    if (semanticsLabel != null) {
      result = Semantics(label: semanticsLabel, child: result);
    }
    return result;
  }
}
