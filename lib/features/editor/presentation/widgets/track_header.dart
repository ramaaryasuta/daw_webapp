import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/daw_track.dart';
import '../../domain/track_mixer.dart';
import '../controllers/audio_meter_controller.dart';
import 'audio_level_meter.dart';
import 'track_color_popover.dart';
import 'track_properties_popover.dart';

const double trackHeaderWidth = 280;
const double trackHeight = 110;

class TrackHeader extends StatefulWidget {
  const TrackHeader({
    super.key,
    required this.name,
    required this.colorValue,
    required this.volumeDb,
    required this.pan,
    required this.isMuted,
    required this.isSolo,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onColorEditStarted,
    required this.onColorPreviewed,
    required this.onColorEditCommitted,
    required this.onColorEditCancelled,
    required this.onColorSelected,
    required this.onMutePressed,
    required this.onSoloPressed,
    required this.onDuplicatePressed,
    required this.onDeletePressed,
    required this.onVolumeChangeStart,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onVolumeReset,
    required this.onPanChangeStart,
    required this.onPanChanged,
    required this.onPanChangeEnd,
    required this.onPanReset,
    required this.onReorderStarted,
    required this.onReorderUpdated,
    required this.onReorderEnded,
    this.isReorderDragging = false,
    this.meterController,
    this.trackId,
  });

  final String name;
  final int colorValue;
  final double volumeDb;
  final double pan;

  final bool isMuted;
  final bool isSolo;
  final bool isSelected;
  final AudioMeterController? meterController;
  final String? trackId;

  final VoidCallback onTap;
  final ValueChanged<String> onRename;
  final VoidCallback onColorEditStarted;
  final ValueChanged<int> onColorPreviewed;
  final VoidCallback onColorEditCommitted;
  final VoidCallback onColorEditCancelled;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onMutePressed;
  final VoidCallback onSoloPressed;
  final VoidCallback onDuplicatePressed;
  final VoidCallback onDeletePressed;

  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeStart;
  final ValueChanged<double> onVolumeChangeEnd;
  final VoidCallback onVolumeReset;
  final ValueChanged<double> onPanChanged;
  final ValueChanged<double> onPanChangeStart;
  final ValueChanged<double> onPanChangeEnd;
  final VoidCallback onPanReset;
  final VoidCallback onReorderStarted;
  final ValueChanged<DragUpdateDetails> onReorderUpdated;
  final VoidCallback onReorderEnded;
  final bool isReorderDragging;

  @override
  State<TrackHeader> createState() => _TrackHeaderState();
}

class _TrackHeaderState extends State<TrackHeader> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final MenuController _colorMenuController = MenuController();
  final MenuController _propertiesMenuController = MenuController();

  bool _isRenaming = false;
  bool _colorEditActive = false;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_handleNameFocusChange);
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_handleNameFocusChange);
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameFocusChange() {
    if (!_nameFocusNode.hasFocus && _isRenaming) {
      _commitRename();
    }
  }

  void _beginRename() {
    if (_isRenaming) {
      return;
    }

    setState(() {
      _isRenaming = true;
      _nameController.text = widget.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isRenaming) {
        return;
      }
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _commitRename() {
    if (!_isRenaming) {
      return;
    }

    final name = _nameController.text.trim();
    setState(() => _isRenaming = false);
    if (name.isNotEmpty && name != widget.name) {
      widget.onRename(name);
    }
    _nameController.text = name.isEmpty ? widget.name : name;
  }

  void _cancelRename() {
    if (!_isRenaming) {
      return;
    }

    setState(() {
      _isRenaming = false;
      _nameController.text = widget.name;
    });
    _nameFocusNode.unfocus();
  }

  void _handleColorMenuOpened() {
    if (_colorEditActive) {
      return;
    }
    _colorEditActive = true;
    widget.onColorEditStarted();
  }

  void _handleColorMenuClosed() {
    if (!_colorEditActive) {
      return;
    }
    _colorEditActive = false;
    widget.onColorEditCancelled();
  }

  void _toggleColorMenu() {
    if (_colorMenuController.isOpen) {
      _colorMenuController.close();
    } else {
      _colorMenuController.open();
    }
  }

  void _commitColor([int? colorValue]) {
    if (!_colorEditActive) {
      return;
    }
    if (colorValue != null) {
      widget.onColorPreviewed(colorValue);
    }
    _colorEditActive = false;
    widget.onColorEditCommitted();
    _colorMenuController.close();
  }

  void _renameFromProperties() {
    _propertiesMenuController.close();
    _beginRename();
  }

  void _deleteFromProperties() {
    _propertiesMenuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onDeletePressed();
      }
    });
  }

  void _duplicateFromProperties() {
    _propertiesMenuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onDuplicatePressed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: widget.isSelected
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surface,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: trackHeaderWidth,
          height: trackHeight,
          padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
          decoration: BoxDecoration(
            color: widget.isReorderDragging
                ? colorScheme.primary.withValues(alpha: 0.08)
                : null,
            border: Border(
              left: BorderSide(
                color: widget.isReorderDragging
                    ? colorScheme.primary.withValues(alpha: 0.9)
                    : Colors.transparent,
                width: widget.isReorderDragging ? 2 : 0,
              ),
              right: BorderSide(color: colorScheme.outlineVariant),
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _TrackReorderHandle(
                trackId: widget.trackId ?? widget.name,
                trackName: widget.name,
                trackColor: Color(widget.colorValue),
                isDragging: widget.isReorderDragging,
                onDragStarted: widget.onReorderStarted,
                onDragUpdate: widget.onReorderUpdated,
                onDragEnd: widget.onReorderEnded,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          MenuAnchor(
                            controller: _colorMenuController,
                            useRootOverlay: true,
                            consumeOutsideTap: true,
                            onOpen: _handleColorMenuOpened,
                            onClose: _handleColorMenuClosed,
                            style: MenuStyle(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.zero,
                              ),
                              backgroundColor: WidgetStatePropertyAll(
                                colorScheme.surfaceContainerHigh,
                              ),
                              elevation: const WidgetStatePropertyAll(8),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                            menuChildren: [
                              TrackColorPopover(
                                key: const ValueKey('track-color-popover'),
                                initialColorValue: widget.colorValue,
                                onPreview: widget.onColorPreviewed,
                                onPresetSelected: _commitColor,
                                onDone: _commitColor,
                                onCancel: _colorMenuController.close,
                              ),
                            ],
                            builder: (context, controller, child) => Tooltip(
                              message: 'Change track color',
                              child: Semantics(
                                button: true,
                                label: 'Change color for ${widget.name}',
                                child: InkResponse(
                                  key: const ValueKey('track-color-swatch'),
                                  onTap: _toggleColorMenu,
                                  radius: 18,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: _ColorDot(
                                      color: Color(widget.colorValue),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: _buildTrackName(context)),

                          MenuAnchor(
                            controller: _propertiesMenuController,
                            useRootOverlay: true,
                            consumeOutsideTap: true,
                            style: MenuStyle(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.zero,
                              ),
                              backgroundColor: WidgetStatePropertyAll(
                                colorScheme.surfaceContainerHigh,
                              ),
                              elevation: const WidgetStatePropertyAll(8),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                            menuChildren: [
                              TrackPropertiesPopover(
                                key: const ValueKey('track-properties-popover'),
                                trackName: widget.name,
                                colorValue: widget.colorValue,
                                pan: widget.pan,
                                onRename: _renameFromProperties,
                                onColorSelected: widget.onColorSelected,
                                onPanChangeStart: widget.onPanChangeStart,
                                onPanChanged: widget.onPanChanged,
                                onPanChangeEnd: widget.onPanChangeEnd,
                                onPanReset: widget.onPanReset,
                                onDuplicate: _duplicateFromProperties,
                                onDelete: _deleteFromProperties,
                              ),
                            ],
                            builder: (context, controller, child) => IconButton(
                              key: const ValueKey('track-properties-button'),
                              tooltip: 'Track actions',
                              iconSize: 18,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              onPressed: () => controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 2),

                    SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          _MixerStateButton(
                            label: 'M',
                            tooltip: 'Mute track',
                            semanticLabel: widget.isMuted
                                ? 'Unmute ${widget.name}'
                                : 'Mute ${widget.name}',
                            active: widget.isMuted,
                            activeColor: colorScheme.error,
                            onPressed: widget.onMutePressed,
                          ),
                          const SizedBox(width: 5),
                          _MixerStateButton(
                            label: 'S',
                            tooltip: 'Solo track',
                            semanticLabel: widget.isSolo
                                ? 'Unsolo ${widget.name}'
                                : 'Solo ${widget.name}',
                            active: widget.isSolo,
                            activeColor: colorScheme.tertiary,
                            onPressed: widget.onSoloPressed,
                          ),
                          const SizedBox(width: 7),
                          const _MixerParameterLabel('VOL'),
                          const SizedBox(width: 2),
                          Expanded(
                            child: _TrackVolumeSlider(
                              valueDb: widget.volumeDb,
                              onChangeStart: widget.onVolumeChangeStart,
                              onChanged: widget.onVolumeChanged,
                              onChangeEnd: widget.onVolumeChangeEnd,
                              onReset: widget.onVolumeReset,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _MixerValueLabel(
                            valueKey: const ValueKey('track-volume-value'),
                            text: formatTrackVolumeDb(widget.volumeDb),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.meterController != null && widget.trackId != null) ...[
                const SizedBox(width: 6),
                TrackStereoMeter(
                  controller: widget.meterController!,
                  trackId: widget.trackId!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackName(BuildContext context) {
    if (_isRenaming) {
      return TapRegion(
        onTapOutside: (_) {
          _commitRename();
          _nameFocusNode.unfocus();
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _cancelRename,
          },
          child: TextField(
            key: const ValueKey('track-name-editor'),
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: true,
            maxLines: 1,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maximumTrackNameLength),
            ],
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              _commitRename();
              _nameFocusNode.unfocus();
            },
          ),
        ),
      );
    }

    return Tooltip(
      message: widget.name,
      child: GestureDetector(
        key: const ValueKey('track-name-label'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _beginRename,
        child: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TrackReorderHandle extends StatelessWidget {
  const _TrackReorderHandle({
    required this.trackId,
    required this.trackName,
    required this.trackColor,
    required this.isDragging,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String trackId;
  final String trackName;
  final Color trackColor;
  final bool isDragging;
  final VoidCallback onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grip = MouseRegion(
      cursor: isDragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab,
      child: SizedBox(
        width: 18,
        height: 38,
        child: Icon(
          Icons.drag_indicator,
          size: 17,
          color: colorScheme.onSurfaceVariant.withValues(
            alpha: isDragging ? 1 : 0.72,
          ),
        ),
      ),
    );

    return Tooltip(
      message: 'Drag to reorder track',
      child: Semantics(
        label: 'Drag $trackName to reorder track',
        child: Draggable<String>(
          key: ValueKey('track-reorder-handle-$trackId'),
          data: trackId,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedbackOffset: const Offset(12, 12),
          onDragStarted: onDragStarted,
          onDragUpdate: onDragUpdate,
          onDragEnd: (_) => onDragEnd(),
          feedback: Material(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
            elevation: 7,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_indicator, size: 16, color: trackColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.38, child: grip),
          child: grip,
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _MixerStateButton extends StatelessWidget {
  const _MixerStateButton({
    required this.label,
    required this.tooltip,
    required this.semanticLabel,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final String semanticLabel;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = active
        ? ThemeData.estimateBrightnessForColor(activeColor) == Brightness.dark
              ? Colors.white
              : Colors.black
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: active,
        label: semanticLabel,
        excludeSemantics: true,
        child: SizedBox(
          width: 24,
          height: 24,
          child: OutlinedButton(
            key: ValueKey('track-${label.toLowerCase()}-button'),
            onPressed: onPressed,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(24, 24)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStatePropertyAll(
                active ? activeColor : colorScheme.surfaceContainerHigh,
              ),
              foregroundColor: WidgetStatePropertyAll(foreground),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: active
                      ? activeColor
                      : colorScheme.outline.withValues(alpha: 0.8),
                ),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MixerParameterLabel extends StatelessWidget {
  const _MixerParameterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MixerValueLabel extends StatelessWidget {
  const _MixerValueLabel({required this.valueKey, required this.text});

  final Key valueKey;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Text(
        text,
        key: valueKey,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrackVolumeSlider extends StatefulWidget {
  const _TrackVolumeSlider({
    required this.valueDb,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final double valueDb;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  State<_TrackVolumeSlider> createState() => _TrackVolumeSliderState();
}

class _TrackVolumeSliderState extends State<_TrackVolumeSlider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 350),
      message:
          '${formatTrackVolumeDb(widget.valueDb)}\nDouble-click to reset to 0 dB',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onReset,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              trackShape: const _UnityMarkedTrackShape(),
              activeTrackColor: _hovered
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.86),
              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.22),
              thumbColor: colorScheme.onSurface,
              overlayColor: colorScheme.primary.withValues(alpha: 0.14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                pressedElevation: 5,
              ),
              thumbSize: WidgetStateProperty.resolveWith((states) {
                final emphasized =
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.dragged);
                return Size.square(emphasized ? 14 : 12);
              }),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              key: const ValueKey('track-volume-slider'),
              value: clampTrackVolumeDb(widget.valueDb),
              min: minimumTrackVolumeDb,
              max: maximumTrackVolumeDb,
              semanticFormatterCallback: formatTrackVolumeDb,
              onChangeStart: widget.onChangeStart,
              onChanged: widget.onChanged,
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnityMarkedTrackShape extends RoundedRectSliderTrackShape {
  const _UnityMarkedTrackShape();

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
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
      textDirection: textDirection,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    const unityFraction =
        (unityTrackVolumeDb - minimumTrackVolumeDb) /
        (maximumTrackVolumeDb - minimumTrackVolumeDb);
    final x = textDirection == TextDirection.ltr
        ? trackRect.left + trackRect.width * unityFraction
        : trackRect.right - trackRect.width * unityFraction;
    final markerPaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!.withValues(alpha: 0.95)
      ..strokeWidth = 1.5;
    context.canvas.drawLine(
      Offset(x, trackRect.top - 3),
      Offset(x, trackRect.bottom + 3),
      markerPaint,
    );
  }
}
