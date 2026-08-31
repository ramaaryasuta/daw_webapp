import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/daw_track.dart';
import '../../domain/master_limiter.dart';
import '../../domain/track_mixer.dart';
import '../controllers/audio_meter_controller.dart';
import 'audio_level_meter.dart';
import 'daw_interaction_hint.dart';
import 'daw_rotary_knob.dart';
import 'master_limiter_panel.dart';
import 'mixer_vertical_fader.dart';
import 'track_filter_fx_rack.dart';

class MixerWorkspace extends ConsumerStatefulWidget {
  const MixerWorkspace({
    super.key,
    required this.meterController,
    required this.onBackToArrange,
  });

  final AudioMeterController meterController;
  final VoidCallback onBackToArrange;

  @override
  ConsumerState<MixerWorkspace> createState() => _MixerWorkspaceState();
}

class _MixerWorkspaceState extends ConsumerState<MixerWorkspace> {
  final ScrollController _channelScrollController = ScrollController();

  @override
  void dispose() {
    _channelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    if (state.tracks.isEmpty) {
      return _EmptyMixer(onBackToArrange: widget.onBackToArrange);
    }

    return ColoredBox(
      key: const ValueKey('mixer-workspace'),
      color: Color.alphaBlend(
        Colors.black.withValues(alpha: .18),
        colors.surface,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 520;
          final masterWidth = constraints.maxWidth < 700 ? 112.0 : 124.0;
          final anyTrackSoloed = state.tracks.any((track) => track.isSolo);
          return Row(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _channelScrollController,
                  thumbVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _channelScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < state.tracks.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: SizedBox(
                              width: compactHeight ? 102 : 108,
                              child: _TrackChannelStrip(
                                key: ValueKey(
                                  'mixer-channel-${state.tracks[index].id}',
                                ),
                                track: state.tracks[index],
                                number: index + 1,
                                selected:
                                    state.selectedTrackId ==
                                    state.tracks[index].id,
                                anyTrackSoloed: anyTrackSoloed,
                                compact: compactHeight,
                                meterController: widget.meterController,
                                onSelect: () => controller.selectTrack(
                                  state.tracks[index].id,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 5,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: colors.outline.withValues(alpha: .9),
                    ),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: .24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: masterWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 9, 8, 15),
                  child: _MasterChannelStrip(
                    volumeDb: state.masterVolumeDb,
                    limiter: state.masterLimiter,
                    compact: compactHeight,
                    meterController: widget.meterController,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackChannelStrip extends ConsumerStatefulWidget {
  const _TrackChannelStrip({
    super.key,
    required this.track,
    required this.number,
    required this.selected,
    required this.anyTrackSoloed,
    required this.compact,
    required this.meterController,
    required this.onSelect,
  });

  final DawTrack track;
  final int number;
  final bool selected;
  final bool anyTrackSoloed;
  final bool compact;
  final AudioMeterController meterController;
  final VoidCallback onSelect;

  @override
  ConsumerState<_TrackChannelStrip> createState() => _TrackChannelStripState();
}

class _TrackChannelStripState extends ConsumerState<_TrackChannelStrip> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'mixer-channel');
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(editorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final accent = Color(widget.track.colorValue);
    final activeFxCount = _activeFxCount(widget.track);
    final subdued =
        widget.track.isMuted || (widget.anyTrackSoloed && !widget.track.isSolo);
    final surface = widget.selected
        ? Color.alphaBlend(
            accent.withValues(alpha: .085),
            colors.surfaceContainerLow,
          )
        : _hovered
        ? Color.alphaBlend(
            colors.onSurface.withValues(alpha: .035),
            colors.surfaceContainerLow,
          )
        : colors.surfaceContainerLow;

    return Semantics(
      container: true,
      selected: widget.selected,
      label: 'Mixer channel ${widget.number}, ${widget.track.name}',
      child: FocusableActionDetector(
        focusNode: _focusNode,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            _focusNode.requestFocus();
            widget.onSelect();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(
                color: _focused
                    ? colors.onSurface.withValues(alpha: .9)
                    : widget.selected
                    ? accent.withValues(alpha: .82)
                    : _hovered
                    ? colors.outline.withValues(alpha: .85)
                    : colors.outlineVariant,
                width: _focused || widget.selected ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: .12),
                        blurRadius: 7,
                      ),
                      const BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: subdued ? .76 : 1,
              child: Column(
                children: [
                  Container(height: 3, color: accent.withValues(alpha: .9)),
                  SizedBox(
                    height: widget.compact ? 42 : 47,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.number.toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Tooltip(
                                  message: widget.track.name,
                                  child: Text(
                                    widget.track.name.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      letterSpacing: .35,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  SizedBox(
                    height: widget.compact ? 29 : 31,
                    child: Center(
                      child: _MixerFxRackButton(
                        trackId: widget.track.id,
                        trackName: widget.track.name,
                        activeFxCount: activeFxCount,
                        accent: accent,
                        meterController: widget.meterController,
                        onOpen: widget.onSelect,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(6, 6, 6, 3),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11141A),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .72),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 25,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TrackStereoMeter(
                                controller: widget.meterController,
                                trackId: widget.track.id,
                                width: 22,
                                height: double.infinity,
                                semanticLabel:
                                    '${widget.track.name} stereo level',
                              ),
                            ),
                          ),
                          Expanded(
                            child: MixerVerticalFader(
                              key: ValueKey('mixer-fader-${widget.track.id}'),
                              valueDb: widget.track.volumeDb,
                              minimumDb: minimumTrackVolumeDb,
                              maximumDb: maximumTrackVolumeDb,
                              unityDb: unityTrackVolumeDb,
                              semanticLabel: '${widget.track.name} volume',
                              valueFormatter: formatTrackVolumeDb,
                              accent: accent,
                              onChangeStart: () {
                                widget.onSelect();
                                controller.beginVolumeChange(widget.track.id);
                              },
                              onChanged: (value) => controller.previewVolume(
                                widget.track.id,
                                value,
                              ),
                              onChangeEnd: (_) => controller.commitVolumeChange(
                                widget.track.id,
                              ),
                              onReset: () =>
                                  controller.resetVolume(widget.track.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    formatTrackVolumeDb(widget.track.volumeDb),
                    key: ValueKey('mixer-volume-value-${widget.track.id}'),
                    style: TextStyle(
                      color: widget.track.volumeDb > 0
                          ? const Color(0xFFF1C84B)
                          : colors.onSurface,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: widget.compact ? 69 : 75,
                    child: DawRotaryKnob(
                      key: ValueKey('mixer-pan-${widget.track.id}'),
                      label: 'PAN',
                      semanticLabel: '${widget.track.name} pan',
                      value: widget.track.pan,
                      minimum: minimumTrackPan,
                      maximum: maximumTrackPan,
                      logarithmic: false,
                      valueLabel: formatTrackPan(widget.track.pan),
                      valueFormatter: formatTrackPan,
                      active: widget.track.pan != centerTrackPan,
                      accent: accent,
                      diameter: widget.compact ? 36 : 40,
                      showCenterTick: true,
                      hint: const DawInteractionHintData(
                        title: 'Drag vertically to adjust pan',
                        detail:
                            'Shift+drag · Fine control   Double-click · Center',
                      ),
                      onChangeStart: () {
                        widget.onSelect();
                        controller.beginPanChange(widget.track.id);
                      },
                      onChanged: (value) =>
                          controller.previewPan(widget.track.id, value),
                      onChangeEnd: (_) =>
                          controller.commitPanChange(widget.track.id),
                      onReset: () => controller.resetPan(widget.track.id),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  SizedBox(
                    height: widget.compact ? 32 : 35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MixerStateButton(
                          key: ValueKey('mixer-mute-${widget.track.id}'),
                          label: 'M',
                          semanticLabel:
                              '${widget.track.name} mute, ${widget.track.isMuted ? 'on' : 'off'}',
                          active: widget.track.isMuted,
                          activeColor: colors.error,
                          onPressed: () {
                            widget.onSelect();
                            controller.toggleMute(widget.track.id);
                          },
                        ),
                        const SizedBox(width: 7),
                        _MixerStateButton(
                          key: ValueKey('mixer-solo-${widget.track.id}'),
                          label: 'S',
                          semanticLabel:
                              '${widget.track.name} solo, ${widget.track.isSolo ? 'on' : 'off'}',
                          active: widget.track.isSolo,
                          activeColor: const Color(0xFFF1C84B),
                          onPressed: () {
                            widget.onSelect();
                            controller.toggleSolo(widget.track.id);
                          },
                        ),
                      ],
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
}

class _MasterChannelStrip extends ConsumerWidget {
  const _MasterChannelStrip({
    required this.volumeDb,
    required this.limiter,
    required this.compact,
    required this.meterController,
  });

  final double volumeDb;
  final MasterLimiterSettings limiter;
  final bool compact;
  final AudioMeterController meterController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    return Container(
      key: const ValueKey('mixer-master-channel'),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: .035),
          colors.surfaceContainerLow,
        ),
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(height: 3, color: accent.withValues(alpha: .78)),
          SizedBox(
            height: compact ? 42 : 47,
            child: Center(
              child: Text(
                'MASTER',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.outline),
          SizedBox(
            height: compact ? 29 : 31,
            child: Center(
              child: _MasterLimiterButton(
                settings: limiter,
                meterController: meterController,
              ),
            ),
          ),
          Divider(height: 1, color: colors.outline),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(7, 6, 7, 3),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1116),
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 27,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: MasterVerticalStereoMeter(
                        controller: meterController,
                        width: 22,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Expanded(
                    child: MixerVerticalFader(
                      key: const ValueKey('mixer-master-fader'),
                      valueDb: volumeDb,
                      minimumDb: minimumMasterVolumeDb,
                      maximumDb: maximumMasterVolumeDb,
                      unityDb: unityMasterVolumeDb,
                      semanticLabel: 'Master volume',
                      valueFormatter: formatMasterVolumeDb,
                      accent: accent,
                      onChangeStart: controller.beginMasterVolumeChange,
                      onChanged: controller.previewMasterVolume,
                      onChangeEnd: controller.commitMasterVolumeChange,
                      onReset: controller.resetMasterVolume,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              formatMasterVolumeDb(volumeDb),
              key: const ValueKey('mixer-master-volume-value'),
              style: TextStyle(
                color: volumeDb > 0
                    ? const Color(0xFFF1C84B)
                    : colors.onSurface,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixerStateButton extends StatelessWidget {
  const _MixerStateButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: active,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        focusColor: colors.onSurface.withValues(alpha: .14),
        hoverColor: colors.onSurface.withValues(alpha: .06),
        child: Container(
          width: 31,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: .24)
                : colors.surfaceContainerHighest,
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: .82)
                  : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? activeColor : colors.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MixerFxRackButton extends StatefulWidget {
  const _MixerFxRackButton({
    required this.trackId,
    required this.trackName,
    required this.activeFxCount,
    required this.accent,
    required this.meterController,
    required this.onOpen,
  });

  final String trackId;
  final String trackName;
  final int activeFxCount;
  final Color accent;
  final AudioMeterController meterController;
  final VoidCallback onOpen;

  @override
  State<_MixerFxRackButton> createState() => _MixerFxRackButtonState();
}

class _MixerFxRackButtonState extends State<_MixerFxRackButton> {
  final OverlayPortalController _overlayController = OverlayPortalController(
    debugLabel: 'mixer-track-fx-rack',
  );
  final ScrollController _overlayScrollController = ScrollController();

  @override
  void dispose() {
    _overlayScrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    widget.onOpen();
    if (_overlayController.isShowing) {
      _overlayController.hide();
    } else {
      _overlayController.show();
    }
  }

  void _close() {
    if (_overlayController.isShowing) _overlayController.hide();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.activeFxCount > 0;
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context, layoutInfo) {
        final anchorRect = MatrixUtils.transformRect(
          layoutInfo.childPaintTransform,
          Offset.zero & layoutInfo.childSize,
        );
        return Positioned.fill(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _close,
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ModalBarrier(
                      color: Colors.transparent,
                      dismissible: true,
                      onDismiss: _close,
                    ),
                  ),
                  CustomSingleChildLayout(
                    delegate: _MixerOverlayLayoutDelegate(
                      anchorRect: anchorRect,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: layoutInfo.overlaySize.height - 16,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: SingleChildScrollView(
                            controller: _overlayScrollController,
                            child: TrackFilterFxRack(
                              key: ValueKey(
                                'mixer-track-filter-fx-${widget.trackId}',
                              ),
                              trackId: widget.trackId,
                              meterController: widget.meterController,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: DawInteractionHint(
        data: DawInteractionHintData(
          title: 'Open Track FX',
          semanticsLabel:
              '${widget.trackName} Track FX, ${active ? '${widget.activeFxCount} active' : 'none active'}',
        ),
        child: Semantics(
          button: true,
          label: '${widget.trackName} Track FX',
          child: InkWell(
            key: ValueKey('mixer-fx-${widget.trackId}'),
            onTap: _toggle,
            borderRadius: BorderRadius.circular(3),
            focusColor: colors.onSurface.withValues(alpha: .14),
            hoverColor: colors.onSurface.withValues(alpha: .06),
            child: Container(
              height: 23,
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? widget.accent.withValues(alpha: .16)
                    : colors.surfaceContainerHighest,
                border: Border.all(
                  color: active
                      ? widget.accent.withValues(alpha: .72)
                      : colors.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                active ? 'FX ${widget.activeFxCount}' : 'FX',
                style: TextStyle(
                  color: active ? widget.accent : colors.onSurfaceVariant,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterLimiterButton extends ConsumerWidget {
  const _MasterLimiterButton({
    required this.settings,
    required this.meterController,
  });

  final MasterLimiterSettings settings;
  final AudioMeterController meterController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      useRootOverlay: true,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(-220, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        MasterLimiterPanel(
          settings: settings,
          meterController: meterController,
          onToggle: controller.toggleMasterLimiter,
          onChangeStart: controller.beginMasterLimiterChange,
          onChanged: controller.previewMasterLimiterChange,
          onChangeEnd: controller.commitMasterLimiterChange,
          onParameterReset: controller.resetMasterLimiterParameter,
          onReset: controller.resetMasterLimiter,
        ),
      ],
      builder: (context, menuController, child) => DawInteractionHint(
        data: DawInteractionHintData(
          title: 'Open Master Limiter',
          detail: settings.enabled ? 'Limiter enabled' : 'Limiter bypassed',
          semanticsLabel:
              'Master limiter, ${settings.enabled ? 'enabled' : 'bypassed'}',
        ),
        child: Semantics(
          button: true,
          toggled: settings.enabled,
          label: 'Master limiter, ${settings.enabled ? 'enabled' : 'bypassed'}',
          child: InkWell(
            key: const ValueKey('mixer-master-limiter-button'),
            onTap: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
            borderRadius: BorderRadius.circular(3),
            focusColor: colors.onSurface.withValues(alpha: .12),
            hoverColor: colors.onSurface.withValues(alpha: .06),
            child: Container(
              height: 23,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: settings.enabled
                    ? colors.primaryContainer.withValues(alpha: .72)
                    : colors.surfaceContainerHighest,
                border: Border.all(
                  color: settings.enabled
                      ? colors.primary.withValues(alpha: .72)
                      : colors.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LIMITER',
                    style: TextStyle(
                      color: settings.enabled
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .45,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: settings.enabled ? colors.primary : colors.outline,
                      shape: BoxShape.circle,
                      boxShadow: settings.enabled
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .4),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
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
}

class _MixerOverlayLayoutDelegate extends SingleChildLayoutDelegate {
  const _MixerOverlayLayoutDelegate({required this.anchorRect});

  final Rect anchorRect;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const edge = 8.0;
    const gap = 4.0;
    final maxLeft = size.width - childSize.width - edge;
    final desiredLeft = anchorRect.left;
    final left = maxLeft < edge
        ? edge
        : desiredLeft.clamp(edge, maxLeft).toDouble();
    final below = anchorRect.bottom + gap;
    final above = anchorRect.top - childSize.height - gap;
    final maxTop = size.height - childSize.height - edge;
    final top = below + childSize.height <= size.height - edge
        ? below
        : above >= edge
        ? above
        : maxTop < edge
        ? edge
        : anchorRect.top.clamp(edge, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_MixerOverlayLayoutDelegate oldDelegate) =>
      oldDelegate.anchorRect != anchorRect;
}

class _EmptyMixer extends StatelessWidget {
  const _EmptyMixer({required this.onBackToArrange});

  final VoidCallback onBackToArrange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('mixer-empty-state'),
      color: colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 30, color: colors.onSurfaceVariant),
            const SizedBox(height: 13),
            Text(
              'NO TRACKS YET',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import audio or add a Track\nto start mixing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('mixer-back-to-arrange'),
              onPressed: onBackToArrange,
              icon: const Icon(Icons.view_timeline_outlined, size: 16),
              label: const Text('Back to Arrange'),
            ),
          ],
        ),
      ),
    );
  }
}

int _activeFxCount(DawTrack track) => [
  track.filterFx.enabled,
  track.eqFx.enabled,
  track.compressorFx.enabled,
  track.delayFx.enabled,
  track.reverbFx.enabled,
].where((enabled) => enabled).length;
