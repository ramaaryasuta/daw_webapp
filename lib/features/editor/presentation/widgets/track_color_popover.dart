import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/track_color.dart';
import '../editor_shortcut_policy.dart';
import '../track_color_palette.dart';

const double _pickerWidth = 248;
const double _saturationValueHeight = 112;

class TrackColorPopover extends StatefulWidget {
  const TrackColorPopover({
    super.key,
    required this.initialColorValue,
    required this.onPreview,
    required this.onPresetSelected,
    required this.onDone,
    required this.onCancel,
  });

  final int initialColorValue;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<TrackColorPopover> createState() => _TrackColorPopoverState();
}

class _TrackColorPopoverState extends State<TrackColorPopover> {
  late HSVColor _hsvColor;
  late final TextEditingController _hexController;
  final FocusNode _hexFocusNode = FocusNode();
  bool _hexIsInvalid = false;

  int get _colorValue => opaqueTrackColor(_hsvColor.toColor().toARGB32());

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(Color(widget.initialColorValue));
    _hexController = TextEditingController(text: trackColorHex(_colorValue));
    _hexFocusNode.addListener(_handleHexFocusChange);
  }

  @override
  void dispose() {
    _hexFocusNode.removeListener(_handleHexFocusChange);
    _hexFocusNode.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _handleHexFocusChange() {
    if (!_hexFocusNode.hasFocus &&
        parseTrackColorHex(_hexController.text) == null) {
      setState(() {
        _hexIsInvalid = false;
        _hexController.text = trackColorHex(_colorValue);
      });
    }
  }

  void _setHsv(HSVColor value, {bool updateHex = true}) {
    final normalized = value.withAlpha(1);
    setState(() {
      _hsvColor = normalized;
      _hexIsInvalid = false;
      if (updateHex) {
        _hexController.text = trackColorHex(_colorValue);
      }
    });
    widget.onPreview(_colorValue);
  }

  void _updateSaturationValue(Offset position) {
    final saturation = (position.dx / _pickerWidth).clamp(0.0, 1.0);
    final value = (1 - position.dy / _saturationValueHeight).clamp(0.0, 1.0);
    _setHsv(_hsvColor.withSaturation(saturation).withValue(value));
  }

  void _handleHexChanged(String value) {
    final parsed = parseTrackColorHex(value);
    setState(() => _hexIsInvalid = parsed == null && value.length >= 6);
    if (parsed == null) {
      return;
    }

    _setHsv(HSVColor.fromColor(Color(parsed)), updateHex: false);
  }

  void _submitHex(String value) {
    final parsed = parseTrackColorHex(value);
    if (parsed == null) {
      setState(() => _hexIsInvalid = true);
      return;
    }
    _setHsv(HSVColor.fromColor(Color(parsed)));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentColor = Color(_colorValue);

    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: FocusTraversalGroup(
          child: SizedBox(
            width: 272,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Track Color',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        trackColorHex(_colorValue),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final preset in trackColorPresets)
                        _PresetSwatch(
                          preset: preset,
                          isSelected: preset.colorValue == _colorValue,
                          onPressed: () =>
                              widget.onPresetSelected(preset.colorValue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Saturation and brightness',
                    value:
                        '${(_hsvColor.saturation * 100).round()} percent saturation, '
                        '${(_hsvColor.value * 100).round()} percent brightness',
                    child: GestureDetector(
                      key: const ValueKey('track-color-saturation-value'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _updateSaturationValue(details.localPosition),
                      onPanStart: (details) =>
                          _updateSaturationValue(details.localPosition),
                      onPanUpdate: (details) =>
                          _updateSaturationValue(details.localPosition),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CustomPaint(
                          painter: _SaturationValuePainter(
                            hue: _hsvColor.hue,
                            saturation: _hsvColor.saturation,
                            value: _hsvColor.value,
                          ),
                          child: const SizedBox(
                            width: _pickerWidth,
                            height: _saturationValueHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _HueSlider(
                    hue: _hsvColor.hue,
                    onChanged: (hue) => _setHsv(_hsvColor.withHue(hue)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        key: const ValueKey('track-color-preview'),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: currentColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: colorScheme.outline),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('track-color-hex-field'),
                          controller: _hexController,
                          focusNode: _hexFocusNode,
                          maxLines: 1,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9a-fA-F#]'),
                            ),
                            LengthLimitingTextInputFormatter(7),
                          ],
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                          decoration: InputDecoration(
                            isDense: true,
                            errorText: _hexIsInvalid ? 'Use #RRGGBB' : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: _handleHexChanged,
                          onSubmitted: _submitHex,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey('track-color-cancel'),
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        key: const ValueKey('track-color-done'),
                        onPressed: widget.onDone,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.preset,
    required this.isSelected,
    required this.onPressed,
  });

  final TrackColorPreset preset;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${preset.label} track color',
      child: Tooltip(
        message: preset.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('track-color-preset-${preset.label.toLowerCase()}'),
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preset.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.outline.withValues(alpha: 0.7),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 17,
                      color: preset.color.computeLuminance() > 0.45
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hue',
      slider: true,
      value: '${hue.round()} degrees',
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              right: 8,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                overlayShape: SliderComponentShape.noOverlay,
                thumbColor: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 2,
                ),
              ),
              child: Slider(
                key: const ValueKey('track-color-hue-slider'),
                value: hue,
                min: 0,
                max: 360,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(bounds),
    );

    final center = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}
