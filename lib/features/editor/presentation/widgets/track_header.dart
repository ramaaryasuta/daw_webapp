import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/daw_track.dart';
import 'track_color_popover.dart';

const double trackHeaderWidth = 280;
const double trackHeight = 110;

enum _TrackAction { rename }

class TrackHeader extends StatefulWidget {
  const TrackHeader({
    super.key,
    required this.name,
    required this.colorValue,
    required this.volume,
    required this.isMuted,
    required this.isSolo,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onColorEditStarted,
    required this.onColorPreviewed,
    required this.onColorEditCommitted,
    required this.onColorEditCancelled,
    required this.onMutePressed,
    required this.onSoloPressed,
    required this.onDeletePressed,
    required this.onVolumeChangeStart,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
  });

  final String name;
  final int colorValue;
  final double volume;

  final bool isMuted;
  final bool isSolo;
  final bool isSelected;

  final VoidCallback onTap;
  final ValueChanged<String> onRename;
  final VoidCallback onColorEditStarted;
  final ValueChanged<int> onColorPreviewed;
  final VoidCallback onColorEditCommitted;
  final VoidCallback onColorEditCancelled;
  final VoidCallback onMutePressed;
  final VoidCallback onSoloPressed;
  final VoidCallback onDeletePressed;

  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeStart;
  final ValueChanged<double> onVolumeChangeEnd;

  @override
  State<TrackHeader> createState() => _TrackHeaderState();
}

class _TrackHeaderState extends State<TrackHeader> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final MenuController _colorMenuController = MenuController();

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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant),
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
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
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                        backgroundColor: WidgetStatePropertyAll(
                          colorScheme.surfaceContainerHigh,
                        ),
                        elevation: const WidgetStatePropertyAll(8),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: colorScheme.outlineVariant),
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

                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<_TrackAction>(
                        tooltip: 'Track actions',
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        onSelected: (action) {
                          switch (action) {
                            case _TrackAction.rename:
                              _beginRename();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _TrackAction.rename,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined, size: 19),
                              title: Text('Rename'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: 'Delete track',
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      onPressed: widget.onDeletePressed,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    _TrackButton(
                      label: 'M',
                      active: widget.isMuted,
                      onPressed: widget.onMutePressed,
                    ),

                    const SizedBox(width: 6),

                    _TrackButton(
                      label: 'S',
                      active: widget.isSolo,
                      onPressed: widget.onSoloPressed,
                    ),

                    const SizedBox(width: 8),

                    const Icon(Icons.volume_down, size: 18),

                    Expanded(
                      child: Slider(
                        value: widget.volume,
                        min: 0,
                        max: 1,
                        onChangeStart: widget.onVolumeChangeStart,
                        onChanged: widget.onVolumeChanged,
                        onChangeEnd: widget.onVolumeChangeEnd,
                      ),
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

class _TrackButton extends StatelessWidget {
  const _TrackButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 28,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Text(label),
      ),
    );
  }
}
