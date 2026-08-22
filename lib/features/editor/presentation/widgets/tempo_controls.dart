import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/tempo_controller.dart';
import '../../application/editor_controller.dart';

class TempoControls extends ConsumerStatefulWidget {
  const TempoControls({super.key});

  @override
  ConsumerState<TempoControls> createState() => _TempoControlsState();
}

class _TempoControlsState extends ConsumerState<TempoControls> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commitEditing();
    }
  }

  void _beginEditing(double bpm) {
    if (_isEditing) {
      return;
    }

    setState(() {
      _isEditing = true;
      _textController.text = _formatBpm(bpm);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isEditing) {
        return;
      }

      _focusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _commitEditing() {
    if (!_isEditing) {
      return;
    }

    final parsed = double.tryParse(_textController.text.replaceAll(',', '.'));

    setState(() {
      _isEditing = false;
    });

    if (parsed != null && parsed.isFinite) {
      ref.read(editorControllerProvider.notifier).setTempoBpm(parsed);
    }

    _textController.text = _formatBpm(ref.read(tempoControllerProvider).bpm);
  }

  void _cancelEditing() {
    if (!_isEditing) {
      return;
    }

    setState(() {
      _isEditing = false;
      _textController.text = _formatBpm(
        ref.read(tempoControllerProvider).bpm,
      );
    });
    _focusNode.unfocus();
  }

  void _adjustBpm(double verticalDelta) {
    final currentBpm = ref.read(tempoControllerProvider).bpm;
    ref
        .read(editorControllerProvider.notifier)
        .previewTempoBpm(currentBpm - verticalDelta * 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final tempo = ref.watch(tempoControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isEditing) {
      _textController.text = _formatBpm(tempo.bpm);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          toggled: tempo.metronomeEnabled,
          label: 'Metronome',
          child: IconButton(
            tooltip: tempo.metronomeEnabled
                ? 'Disable metronome'
                : 'Enable metronome',
            isSelected: tempo.metronomeEnabled,
            onPressed: () {
              ref.read(tempoControllerProvider.notifier).toggleMetronome();
            },
            style: IconButton.styleFrom(
              minimumSize: const Size.square(36),
              maximumSize: const Size.square(36),
              backgroundColor: tempo.metronomeEnabled
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: tempo.metronomeEnabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.music_note_outlined, size: 19),
            selectedIcon: const Icon(Icons.music_note, size: 19),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Tempo (click to edit, drag vertically to adjust)',
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                if (_isEditing)
                  SizedBox(
                    width: 56,
                    child: TapRegion(
                      onTapOutside: (_) {
                        _commitEditing();
                        _focusNode.unfocus();
                      },
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              _cancelEditing,
                        },
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ]),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 5),
                            border: UnderlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            _commitEditing();
                            _focusNode.unfocus();
                          },
                        ),
                      ),
                    ),
                  )
                else
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _beginEditing(tempo.bpm),
                      onVerticalDragStart: (_) {
                        ref
                            .read(editorControllerProvider.notifier)
                            .beginTempoChange();
                      },
                      onVerticalDragUpdate: (details) {
                        _adjustBpm(details.primaryDelta ?? 0);
                      },
                      onVerticalDragEnd: (_) {
                        ref
                            .read(editorControllerProvider.notifier)
                            .commitTempoChange();
                      },
                      onVerticalDragCancel: () {
                        ref
                            .read(editorControllerProvider.notifier)
                            .commitTempoChange();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          _formatBpm(tempo.bpm),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  'BPM',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatBpm(double bpm) {
    if ((bpm - bpm.round()).abs() < 0.0001) {
      return bpm.round().toString();
    }

    return bpm.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}
