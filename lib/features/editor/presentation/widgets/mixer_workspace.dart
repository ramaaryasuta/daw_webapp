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
          final masterWidth = constraints.maxWidth < 420 ? 108.0 : 128.0;
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
                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 16),
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
                              width: 112,
                              child: _TrackChannelStrip(
                                key: ValueKey(
                                  'mixer-channel-${state.tracks[index].id}',
                                ),
                                track: state.tracks[index],
                                number: index + 1,
                                selected:
                                    state.selectedTrackId ==
                                    state.tracks[index].id,
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
              Container(width: 1, color: colors.outline.withValues(alpha: .82)),
              SizedBox(
                width: masterWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 10, 8, 16),
                  child: _MasterChannelStrip(
                    volumeDb: state.masterVolumeDb,
                    limiter: state.masterLimiter,
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

class _TrackChannelStrip extends ConsumerWidget {
  const _TrackChannelStrip({
    super.key,
    required this.track,
    required this.number,
    required this.selected,
    required this.meterController,
    required this.onSelect,
  });

  final DawTrack track;
  final int number;
  final bool selected;
  final AudioMeterController meterController;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final accent = Color(track.colorValue);
    final activeFxCount = _activeFxCount(track);

    return Semantics(
      container: true,
      selected: selected,
      label: 'Mixer channel $number, ${track.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onSelect,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    accent.withValues(alpha: .08),
                    colors.surfaceContainerLow,
                  )
                : colors.surfaceContainerLow,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: .82)
                  : colors.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(height: 3, color: accent.withValues(alpha: .9)),
              SizedBox(
                height: 54,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 19,
                        child: Text(
                          number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Tooltip(
                          message: track.name,
                          child: Text(
                            track.name.toUpperCase(),
                            maxLines: 2,
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
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              SizedBox(
                height: 34,
                child: Center(
                  child: _MixerFxRackButton(
                    trackId: track.id,
                    trackName: track.name,
                    activeFxCount: activeFxCount,
                    accent: accent,
                    meterController: meterController,
                    onOpen: onSelect,
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
                            controller: meterController,
                            trackId: track.id,
                            width: 22,
                            height: double.infinity,
                            semanticLabel: '${track.name} stereo level',
                          ),
                        ),
                      ),
                      Expanded(
                        child: MixerVerticalFader(
                          key: ValueKey('mixer-fader-${track.id}'),
                          valueDb: track.volumeDb,
                          minimumDb: minimumTrackVolumeDb,
                          maximumDb: maximumTrackVolumeDb,
                          unityDb: unityTrackVolumeDb,
                          semanticLabel: '${track.name} volume',
                          valueFormatter: formatTrackVolumeDb,
                          accent: accent,
                          onChangeStart: () {
                            onSelect();
                            controller.beginVolumeChange(track.id);
                          },
                          onChanged: (value) =>
                              controller.previewVolume(track.id, value),
                          onChangeEnd: (_) =>
                              controller.commitVolumeChange(track.id),
                          onReset: () => controller.resetVolume(track.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                formatTrackVolumeDb(track.volumeDb),
                key: ValueKey('mixer-volume-value-${track.id}'),
                style: TextStyle(
                  color: track.volumeDb > 0
                      ? const Color(0xFFF1C84B)
                      : colors.onSurface,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 84,
                child: DawRotaryKnob(
                  key: ValueKey('mixer-pan-${track.id}'),
                  label: 'PAN',
                  semanticLabel: '${track.name} pan',
                  value: track.pan,
                  minimum: minimumTrackPan,
                  maximum: maximumTrackPan,
                  logarithmic: false,
                  valueLabel: formatTrackPan(track.pan),
                  valueFormatter: formatTrackPan,
                  active: track.pan != centerTrackPan,
                  accent: accent,
                  hint: const DawInteractionHintData(
                    title: 'Drag vertically to adjust pan',
                    detail: 'Shift+drag · Fine control   Double-click · Center',
                  ),
                  onChangeStart: () {
                    onSelect();
                    controller.beginPanChange(track.id);
                  },
                  onChanged: (value) => controller.previewPan(track.id, value),
                  onChangeEnd: (_) => controller.commitPanChange(track.id),
                  onReset: () => controller.resetPan(track.id),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              SizedBox(
                height: 37,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MixerStateButton(
                      key: ValueKey('mixer-mute-${track.id}'),
                      label: 'M',
                      semanticLabel:
                          '${track.name} mute, ${track.isMuted ? 'on' : 'off'}',
                      active: track.isMuted,
                      activeColor: colors.error,
                      onPressed: () {
                        onSelect();
                        controller.toggleMute(track.id);
                      },
                    ),
                    const SizedBox(width: 7),
                    _MixerStateButton(
                      key: ValueKey('mixer-solo-${track.id}'),
                      label: 'S',
                      semanticLabel:
                          '${track.name} solo, ${track.isSolo ? 'on' : 'off'}',
                      active: track.isSolo,
                      activeColor: const Color(0xFFF1C84B),
                      onPressed: () {
                        onSelect();
                        controller.toggleSolo(track.id);
                      },
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
}

class _MasterChannelStrip extends ConsumerWidget {
  const _MasterChannelStrip({
    required this.volumeDb,
    required this.limiter,
    required this.meterController,
  });

  final double volumeDb;
  final MasterLimiterSettings limiter;
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
            height: 54,
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
            height: 34,
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
      builder: (context, menuController, child) => Semantics(
        button: true,
        toggled: settings.enabled,
        label: 'Master limiter, ${settings.enabled ? 'enabled' : 'bypassed'}',
        child: InkWell(
          key: const ValueKey('mixer-master-limiter-button'),
          onTap: () => menuController.isOpen
              ? menuController.close()
              : menuController.open(),
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: settings.enabled
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              border: Border.all(
                color: settings.enabled
                    ? colors.primary.withValues(alpha: .72)
                    : colors.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'LIM',
              style: TextStyle(
                color: settings.enabled
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
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
