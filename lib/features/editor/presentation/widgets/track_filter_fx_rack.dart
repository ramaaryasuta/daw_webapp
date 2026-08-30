import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/tempo_controller.dart';
import '../../domain/daw_track.dart';
import '../../domain/track_filter_fx.dart';
import '../../domain/track_eq_fx.dart';
import '../../domain/track_compressor_fx.dart';
import '../../domain/track_delay_fx.dart';
import '../../domain/track_fx_chain.dart';
import '../controllers/audio_meter_controller.dart';
import '../editor_shortcut_policy.dart';
import 'daw_interaction_hint.dart';

class TrackFilterFxRack extends ConsumerStatefulWidget {
  const TrackFilterFxRack({
    super.key,
    required this.trackId,
    required this.meterController,
  });

  final String trackId;
  final AudioMeterController meterController;

  @override
  ConsumerState<TrackFilterFxRack> createState() => _TrackFilterFxRackState();
}

class _TrackFilterFxRackState extends ConsumerState<TrackFilterFxRack> {
  TrackFilterFx? _filterPreview;
  TrackEqFx? _eqPreview;
  TrackCompressorFx? _compressorPreview;
  TrackDelayFx? _delayPreview;
  TrackFxType _selectedModule = TrackFxType.filter;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      editorControllerProvider.select(
        (state) => state.tracks
            .where((track) => track.id == widget.trackId)
            .firstOrNull,
      ),
    );
    if (track == null) {
      return const SizedBox.shrink();
    }
    final filter = _filterPreview ?? track.filterFx;
    final eq = _eqPreview ?? track.eqFx;
    final compressor = _compressorPreview ?? track.compressorFx;
    final delay = _delayPreview ?? track.delayFx;
    final bpm = ref.watch(tempoControllerProvider.select((state) => state.bpm));
    final colorScheme = Theme.of(context).colorScheme;
    final accent = Color(track.colorValue);

    return EditorShortcutScope(
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 392,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TrackFxRackHeader(
                  trackName: track.name,
                  enabled:
                      filter.enabled ||
                      eq.enabled ||
                      compressor.enabled ||
                      delay.enabled,
                  accent: accent,
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _FxChainSlots(
                  order: track.fxChainOrder,
                  selected: _selectedModule,
                  filterActive: filter.enabled,
                  eqActive: eq.enabled,
                  compressorActive: compressor.enabled,
                  delayActive: delay.enabled,
                  accent: accent,
                  onSelected: (module) => setState(() {
                    _selectedModule = module;
                    _filterPreview = null;
                    _eqPreview = null;
                    _compressorPreview = null;
                    _delayPreview = null;
                  }),
                  onReorder: (oldIndex, newIndex) =>
                      _reorderFx(track.fxChainOrder, oldIndex, newIndex),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                if (_selectedModule == TrackFxType.filter) ...[
                  _EffectHeader(
                    title: 'FILTER',
                    enabled: filter.enabled,
                    accent: accent,
                    toggleKey: const ValueKey('filter-fx-global-toggle'),
                    onToggle: () => ref
                        .read(editorControllerProvider.notifier)
                        .toggleFilterFx(widget.trackId),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'FREQUENCY RESPONSE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          height: 126,
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x38000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CustomPaint(
                              key: const ValueKey('track-filter-response'),
                              painter: _FilterResponsePainter(
                                filter: filter,
                                accent: accent,
                                gridColor: colorScheme.outlineVariant,
                                labelColor: colorScheme.onSurfaceVariant,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _FilterModulePanel(
                            title: 'HIGH PASS',
                            enabled: filter.highPass.enabled,
                            globallyEnabled: filter.enabled,
                            accent: accent,
                            frequencyHz: filter.highPass.frequencyHz,
                            q: filter.highPass.q,
                            frequencyParameter:
                                TrackFilterParameter.highPassFrequency,
                            qParameter: TrackFilterParameter.highPassQ,
                            onToggle: () => ref
                                .read(editorControllerProvider.notifier)
                                .toggleTrackFilterModule(
                                  widget.trackId,
                                  highPass: true,
                                ),
                            onPreview: (parameter, value) =>
                                _previewParameter(track, parameter, value),
                            onCommit: (parameter, value) =>
                                _commitParameter(parameter, value),
                            onBegin: _beginParameter,
                            onReset: _resetParameter,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 146,
                          color: colorScheme.outlineVariant,
                        ),
                        Expanded(
                          child: _FilterModulePanel(
                            title: 'LOW PASS',
                            enabled: filter.lowPass.enabled,
                            globallyEnabled: filter.enabled,
                            accent: accent,
                            frequencyHz: filter.lowPass.frequencyHz,
                            q: filter.lowPass.q,
                            frequencyParameter:
                                TrackFilterParameter.lowPassFrequency,
                            qParameter: TrackFilterParameter.lowPassQ,
                            onToggle: () => ref
                                .read(editorControllerProvider.notifier)
                                .toggleTrackFilterModule(
                                  widget.trackId,
                                  highPass: false,
                                ),
                            onPreview: (parameter, value) =>
                                _previewParameter(track, parameter, value),
                            onCommit: (parameter, value) =>
                                _commitParameter(parameter, value),
                            onBegin: _beginParameter,
                            onReset: _resetParameter,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedModule == TrackFxType.eq) ...[
                  _EffectHeader(
                    title: '3-BAND EQ',
                    enabled: eq.enabled,
                    accent: const Color(0xFF79B8FF),
                    toggleKey: const ValueKey('track-eq-global-toggle'),
                    onToggle: () => ref
                        .read(editorControllerProvider.notifier)
                        .toggleTrackEq(widget.trackId),
                    onReset: () => ref
                        .read(editorControllerProvider.notifier)
                        .resetTrackEq(widget.trackId),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FREQUENCY RESPONSE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.15,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          height: 142,
                          decoration: BoxDecoration(
                            color: const Color(0xFF101317),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x48000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: CustomPaint(
                              key: const ValueKey('track-eq-response'),
                              painter: _EqResponsePainter(
                                eq: eq,
                                gridColor: colorScheme.outlineVariant,
                                labelColor: colorScheme.onSurfaceVariant,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: eq.enabled ? 1 : 0.55,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _eqKnob(
                                track: track,
                                eq: eq,
                                parameter: TrackEqParameter.lowGain,
                                label: 'LOW',
                                value: eq.lowGainDb,
                                minimum: minimumEqGainDb,
                                maximum: maximumEqGainDb,
                                valueLabel: formatEqGain(eq.lowGainDb),
                                accent: const Color(0xFF64C7D0),
                              ),
                              _eqKnob(
                                track: track,
                                eq: eq,
                                parameter: TrackEqParameter.midGain,
                                label: 'MID',
                                value: eq.midGainDb,
                                minimum: minimumEqGainDb,
                                maximum: maximumEqGainDb,
                                valueLabel: formatEqGain(eq.midGainDb),
                                accent: const Color(0xFFE4B85D),
                              ),
                              _eqKnob(
                                track: track,
                                eq: eq,
                                parameter: TrackEqParameter.highGain,
                                label: 'HIGH',
                                value: eq.highGainDb,
                                minimum: minimumEqGainDb,
                                maximum: maximumEqGainDb,
                                valueLabel: formatEqGain(eq.highGainDb),
                                accent: const Color(0xFFC28BE8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 9),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _eqKnob(
                                track: track,
                                eq: eq,
                                parameter: TrackEqParameter.midFrequency,
                                label: 'MID FREQ',
                                value: eq.midFrequencyHz,
                                minimum: minimumEqMidFrequencyHz,
                                maximum: maximumEqMidFrequencyHz,
                                logarithmic: true,
                                valueLabel: formatEqFrequency(
                                  eq.midFrequencyHz,
                                ),
                                accent: const Color(0xFFE4B85D),
                              ),
                              const SizedBox(width: 30),
                              _eqKnob(
                                track: track,
                                eq: eq,
                                parameter: TrackEqParameter.midQ,
                                label: 'Q',
                                value: eq.midQ,
                                minimum: minimumEqMidQ,
                                maximum: maximumEqMidQ,
                                valueLabel: eq.midQ.toStringAsFixed(2),
                                accent: const Color(0xFFE4B85D),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_selectedModule == TrackFxType.compressor) ...[
                  _EffectHeader(
                    title: 'COMPRESSOR',
                    enabled: compressor.enabled,
                    accent: const Color(0xFFFFB45E),
                    toggleKey: const ValueKey('track-compressor-toggle'),
                    onToggle: () => ref
                        .read(editorControllerProvider.notifier)
                        .toggleTrackCompressor(widget.trackId),
                    onReset: () => ref
                        .read(editorControllerProvider.notifier)
                        .resetTrackCompressor(widget.trackId),
                    resetKey: const ValueKey('track-compressor-reset'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: _GainReductionMeter(
                      trackId: widget.trackId,
                      controller: widget.meterController,
                      enabled: compressor.enabled,
                      accent: const Color(0xFFFFB45E),
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: compressor.enabled ? 1 : 0.5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _compressorKnob(
                                track: track,
                                compressor: compressor,
                                parameter: TrackCompressorParameter.threshold,
                                label: 'THRESHOLD',
                                value: compressor.thresholdDb,
                                minimum: minimumCompressorThresholdDb,
                                maximum: maximumCompressorThresholdDb,
                                valueLabel: formatCompressorThreshold(
                                  compressor.thresholdDb,
                                ),
                              ),
                              _compressorKnob(
                                track: track,
                                compressor: compressor,
                                parameter: TrackCompressorParameter.ratio,
                                label: 'RATIO',
                                value: compressor.ratio,
                                minimum: minimumCompressorRatio,
                                maximum: maximumCompressorRatio,
                                valueLabel: formatCompressorRatio(
                                  compressor.ratio,
                                ),
                              ),
                              _compressorKnob(
                                track: track,
                                compressor: compressor,
                                parameter: TrackCompressorParameter.makeupGain,
                                label: 'MAKEUP',
                                value: compressor.makeupGainDb,
                                minimum: minimumCompressorMakeupGainDb,
                                maximum: maximumCompressorMakeupGainDb,
                                valueLabel: formatCompressorMakeup(
                                  compressor.makeupGainDb,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 9),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _compressorKnob(
                                track: track,
                                compressor: compressor,
                                parameter: TrackCompressorParameter.attack,
                                label: 'ATTACK',
                                value: compressor.attackSeconds,
                                minimum: minimumCompressorAttackSeconds,
                                maximum: maximumCompressorAttackSeconds,
                                logarithmic: true,
                                valueLabel: formatCompressorAttack(
                                  compressor.attackSeconds,
                                ),
                              ),
                              const SizedBox(width: 30),
                              _compressorKnob(
                                track: track,
                                compressor: compressor,
                                parameter: TrackCompressorParameter.release,
                                label: 'RELEASE',
                                value: compressor.releaseSeconds,
                                minimum: minimumCompressorReleaseSeconds,
                                maximum: maximumCompressorReleaseSeconds,
                                logarithmic: true,
                                valueLabel: formatCompressorRelease(
                                  compressor.releaseSeconds,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  _EffectHeader(
                    title: 'DELAY',
                    enabled: delay.enabled,
                    accent: const Color(0xFF7CD7C4),
                    toggleKey: const ValueKey('track-delay-toggle'),
                    onToggle: () => ref
                        .read(editorControllerProvider.notifier)
                        .toggleTrackDelay(widget.trackId),
                    onReset: () => ref
                        .read(editorControllerProvider.notifier)
                        .resetTrackDelay(widget.trackId),
                    resetKey: const ValueKey('track-delay-reset'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                    child: Container(
                      height: 82,
                      decoration: BoxDecoration(
                        color: const Color(0xFF101615),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: CustomPaint(
                          key: const ValueKey('track-delay-repeats'),
                          painter: _DelayRepeatsPainter(
                            delayTimeSeconds: effectiveDelayTimeSeconds(
                              delay,
                              bpm,
                            ),
                            feedback: delay.feedback,
                            active: delay.enabled,
                            accent: const Color(0xFF7CD7C4),
                            gridColor: colorScheme.outlineVariant,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: delay.enabled ? 1 : 0.5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Opacity(
                            opacity: delay.syncToBpm ? 0.42 : 1,
                            child: IgnorePointer(
                              ignoring: delay.syncToBpm,
                              child: _delayKnob(
                                track: track,
                                delay: delay,
                                parameter: TrackDelayParameter.time,
                                label: 'TIME',
                                value: delay.timeSeconds,
                                minimum: minimumDelayTimeSeconds,
                                maximum: maximumDelayTimeSeconds,
                                logarithmic: true,
                                valueLabel: delay.syncToBpm
                                    ? delay.syncDivision.label
                                    : formatDelayTime(delay.timeSeconds),
                              ),
                            ),
                          ),
                          _delayKnob(
                            track: track,
                            delay: delay,
                            parameter: TrackDelayParameter.feedback,
                            label: 'FEEDBACK',
                            value: delay.feedback,
                            minimum: minimumDelayFeedback,
                            maximum: maximumDelayFeedback,
                            valueLabel: formatDelayPercent(delay.feedback),
                          ),
                          _delayKnob(
                            track: track,
                            delay: delay,
                            parameter: TrackDelayParameter.mix,
                            label: 'MIX',
                            value: delay.mix,
                            minimum: minimumDelayMix,
                            maximum: maximumDelayMix,
                            valueLabel: formatDelayPercent(delay.mix),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Sync delay time to project BPM',
                          child: _CompactPowerButton(
                            key: const ValueKey('track-delay-sync'),
                            label: delay.syncToBpm ? 'SYNC ON' : 'SYNC OFF',
                            enabled: delay.syncToBpm,
                            accent: const Color(0xFF7CD7C4),
                            onPressed: () => ref
                                .read(editorControllerProvider.notifier)
                                .toggleTrackDelaySync(widget.trackId),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _DelayDivisionSelector(
                            selected: delay.syncDivision,
                            enabled: delay.syncToBpm,
                            onSelected: (division) => ref
                                .read(editorControllerProvider.notifier)
                                .setTrackDelayDivision(
                                  widget.trackId,
                                  division,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _eqKnob({
    required DawTrack track,
    required TrackEqFx eq,
    required TrackEqParameter parameter,
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required String valueLabel,
    required Color accent,
    bool logarithmic = false,
  }) {
    return _RotaryKnob(
      key: ValueKey('$parameter-knob'),
      label: label,
      semanticLabel: switch (parameter) {
        TrackEqParameter.lowGain => 'Low EQ gain',
        TrackEqParameter.midGain => 'Mid EQ gain',
        TrackEqParameter.midFrequency => 'Mid EQ frequency',
        TrackEqParameter.midQ => 'Mid EQ Q',
        TrackEqParameter.highGain => 'High EQ gain',
      },
      value: value,
      minimum: minimum,
      maximum: maximum,
      logarithmic: logarithmic,
      valueLabel: valueLabel,
      valueFormatter: switch (parameter) {
        TrackEqParameter.lowGain ||
        TrackEqParameter.midGain ||
        TrackEqParameter.highGain => formatEqGain,
        TrackEqParameter.midFrequency => formatEqFrequency,
        TrackEqParameter.midQ => (value) => value.toStringAsFixed(2),
      },
      active: eq.enabled,
      accent: accent,
      onChangeStart: () => ref
          .read(editorControllerProvider.notifier)
          .beginTrackEqChange(widget.trackId, parameter),
      onChanged: (value) {
        final base = _eqPreview ?? track.eqFx;
        setState(() => _eqPreview = _withEqParameter(base, parameter, value));
        ref
            .read(editorControllerProvider.notifier)
            .previewTrackEqChange(widget.trackId, parameter, value);
      },
      onChangeEnd: (value) {
        ref
            .read(editorControllerProvider.notifier)
            .commitTrackEqChange(widget.trackId, parameter, value);
        if (mounted) setState(() => _eqPreview = null);
      },
      onReset: () {
        ref
            .read(editorControllerProvider.notifier)
            .resetTrackEqParameter(widget.trackId, parameter);
        setState(() => _eqPreview = null);
      },
    );
  }

  Widget _compressorKnob({
    required DawTrack track,
    required TrackCompressorFx compressor,
    required TrackCompressorParameter parameter,
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required String valueLabel,
    bool logarithmic = false,
  }) {
    return _RotaryKnob(
      key: ValueKey('$parameter-knob'),
      label: label,
      semanticLabel: switch (parameter) {
        TrackCompressorParameter.threshold => 'Compressor threshold',
        TrackCompressorParameter.ratio => 'Compressor ratio',
        TrackCompressorParameter.attack => 'Compressor attack',
        TrackCompressorParameter.release => 'Compressor release',
        TrackCompressorParameter.makeupGain => 'Compressor makeup gain',
      },
      value: value,
      minimum: minimum,
      maximum: maximum,
      logarithmic: logarithmic,
      valueLabel: valueLabel,
      valueFormatter: switch (parameter) {
        TrackCompressorParameter.threshold => formatCompressorThreshold,
        TrackCompressorParameter.ratio => formatCompressorRatio,
        TrackCompressorParameter.attack => formatCompressorAttack,
        TrackCompressorParameter.release => formatCompressorRelease,
        TrackCompressorParameter.makeupGain => formatCompressorMakeup,
      },
      active: compressor.enabled,
      accent: const Color(0xFFFFB45E),
      onChangeStart: () => ref
          .read(editorControllerProvider.notifier)
          .beginTrackCompressorChange(widget.trackId, parameter),
      onChanged: (value) {
        final base = _compressorPreview ?? track.compressorFx;
        setState(
          () => _compressorPreview = _withCompressorParameter(
            base,
            parameter,
            value,
          ),
        );
        ref
            .read(editorControllerProvider.notifier)
            .previewTrackCompressorChange(widget.trackId, parameter, value);
      },
      onChangeEnd: (value) {
        ref
            .read(editorControllerProvider.notifier)
            .commitTrackCompressorChange(widget.trackId, parameter, value);
        if (mounted) setState(() => _compressorPreview = null);
      },
      onReset: () {
        ref
            .read(editorControllerProvider.notifier)
            .resetTrackCompressorParameter(widget.trackId, parameter);
        setState(() => _compressorPreview = null);
      },
    );
  }

  Widget _delayKnob({
    required DawTrack track,
    required TrackDelayFx delay,
    required TrackDelayParameter parameter,
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required String valueLabel,
    bool logarithmic = false,
  }) {
    final hint = switch (parameter) {
      TrackDelayParameter.time =>
        'Drag vertically to adjust delay time. Double-click to reset.',
      TrackDelayParameter.feedback => 'Controls how many echoes repeat',
      TrackDelayParameter.mix => 'Blend dry and delayed signal',
    };
    return Tooltip(
      message: hint,
      child: _RotaryKnob(
        key: ValueKey('$parameter-knob'),
        label: label,
        semanticLabel: switch (parameter) {
          TrackDelayParameter.time => 'Delay time',
          TrackDelayParameter.feedback => 'Delay feedback',
          TrackDelayParameter.mix => 'Delay mix',
        },
        value: value,
        minimum: minimum,
        maximum: maximum,
        logarithmic: logarithmic,
        valueLabel: valueLabel,
        valueFormatter: switch (parameter) {
          TrackDelayParameter.time => formatDelayTime,
          TrackDelayParameter.feedback ||
          TrackDelayParameter.mix => formatDelayPercent,
        },
        active: delay.enabled,
        accent: const Color(0xFF7CD7C4),
        onChangeStart: () => ref
            .read(editorControllerProvider.notifier)
            .beginTrackDelayChange(widget.trackId, parameter),
        onChanged: (value) {
          final base = _delayPreview ?? track.delayFx;
          setState(
            () => _delayPreview = _withDelayParameter(base, parameter, value),
          );
          ref
              .read(editorControllerProvider.notifier)
              .previewTrackDelayChange(widget.trackId, parameter, value);
        },
        onChangeEnd: (value) {
          ref
              .read(editorControllerProvider.notifier)
              .commitTrackDelayChange(widget.trackId, parameter, value);
          if (mounted) setState(() => _delayPreview = null);
        },
        onReset: () {
          ref
              .read(editorControllerProvider.notifier)
              .resetTrackDelayParameter(widget.trackId, parameter);
          setState(() => _delayPreview = null);
        },
      ),
    );
  }

  void _beginParameter(TrackFilterParameter parameter) {
    ref
        .read(editorControllerProvider.notifier)
        .beginTrackFilterChange(widget.trackId, parameter);
  }

  void _previewParameter(
    DawTrack track,
    TrackFilterParameter parameter,
    double value,
  ) {
    final base = _filterPreview ?? track.filterFx;
    setState(() => _filterPreview = _withParameter(base, parameter, value));
    ref
        .read(editorControllerProvider.notifier)
        .previewTrackFilterChange(widget.trackId, parameter, value);
  }

  void _commitParameter(TrackFilterParameter parameter, double value) {
    ref
        .read(editorControllerProvider.notifier)
        .commitTrackFilterChange(widget.trackId, parameter, value);
    if (mounted) {
      setState(() => _filterPreview = null);
    }
  }

  void _resetParameter(TrackFilterParameter parameter) {
    ref
        .read(editorControllerProvider.notifier)
        .resetTrackFilterParameter(widget.trackId, parameter);
    setState(() => _filterPreview = null);
  }

  void _reorderFx(List<TrackFxType> current, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final reordered = [...current];
    final effect = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, effect);
    ref
        .read(editorControllerProvider.notifier)
        .reorderTrackFx(widget.trackId, reordered);
  }
}

TrackEqFx _withEqParameter(
  TrackEqFx eq,
  TrackEqParameter parameter,
  double value,
) {
  return switch (parameter) {
    TrackEqParameter.lowGain => eq.copyWith(lowGainDb: value),
    TrackEqParameter.midGain => eq.copyWith(midGainDb: value),
    TrackEqParameter.midFrequency => eq.copyWith(midFrequencyHz: value),
    TrackEqParameter.midQ => eq.copyWith(midQ: value),
    TrackEqParameter.highGain => eq.copyWith(highGainDb: value),
  };
}

TrackCompressorFx _withCompressorParameter(
  TrackCompressorFx compressor,
  TrackCompressorParameter parameter,
  double value,
) {
  return switch (parameter) {
    TrackCompressorParameter.threshold => compressor.copyWith(
      thresholdDb: value,
    ),
    TrackCompressorParameter.ratio => compressor.copyWith(ratio: value),
    TrackCompressorParameter.attack => compressor.copyWith(
      attackSeconds: value,
    ),
    TrackCompressorParameter.release => compressor.copyWith(
      releaseSeconds: value,
    ),
    TrackCompressorParameter.makeupGain => compressor.copyWith(
      makeupGainDb: value,
    ),
  };
}

TrackDelayFx _withDelayParameter(
  TrackDelayFx delay,
  TrackDelayParameter parameter,
  double value,
) {
  return switch (parameter) {
    TrackDelayParameter.time => delay.copyWith(timeSeconds: value),
    TrackDelayParameter.feedback => delay.copyWith(feedback: value),
    TrackDelayParameter.mix => delay.copyWith(mix: value),
  };
}

TrackFilterFx _withParameter(
  TrackFilterFx filter,
  TrackFilterParameter parameter,
  double value,
) {
  return switch (parameter) {
    TrackFilterParameter.highPassFrequency => filter.copyWith(
      highPass: filter.highPass.copyWith(frequencyHz: value),
    ),
    TrackFilterParameter.highPassQ => filter.copyWith(
      highPass: filter.highPass.copyWith(q: value),
    ),
    TrackFilterParameter.lowPassFrequency => filter.copyWith(
      lowPass: filter.lowPass.copyWith(frequencyHz: value),
    ),
    TrackFilterParameter.lowPassQ => filter.copyWith(
      lowPass: filter.lowPass.copyWith(q: value),
    ),
  };
}

class _TrackFxRackHeader extends StatelessWidget {
  const _TrackFxRackHeader({
    required this.trackName,
    required this.enabled,
    required this.accent,
  });

  final String trackName;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: enabled ? accent : colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRACK FX',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Track: $trackName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            enabled ? '● ON' : '○ OFF',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: enabled ? accent : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GainReductionMeter extends StatelessWidget {
  const _GainReductionMeter({
    required this.trackId,
    required this.controller,
    required this.enabled,
    required this.accent,
  });

  final String trackId;
  final AudioMeterController controller;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101317),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x48000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final reduction = enabled
              ? controller.compressorReductionForTrack(trackId)
              : 0.0;
          final fraction = (-reduction / 24).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'GAIN REDUCTION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'GR  ${reduction.toStringAsFixed(1)} dB',
                    key: const ValueKey('compressor-gr-value'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: enabled ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF080A0D),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth * fraction,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: enabled ? 0.82 : 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0'),
                    Text('-3'),
                    Text('-6'),
                    Text('-12'),
                    Text('-24 dB'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DelayDivisionSelector extends StatelessWidget {
  const _DelayDivisionSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final DelaySyncDivision selected;
  final bool enabled;
  final ValueChanged<DelaySyncDivision> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const accent = Color(0xFF7CD7C4);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final division in DelaySyncDivision.values)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: InkWell(
                key: ValueKey('delay-division-${division.name}'),
                onTap: enabled ? () => onSelected(division) : null,
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 24,
                  constraints: const BoxConstraints(minWidth: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == division
                        ? accent.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: selected == division
                          ? accent.withValues(alpha: 0.8)
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    division.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected == division
                          ? accent
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DelayRepeatsPainter extends CustomPainter {
  const _DelayRepeatsPainter({
    required this.delayTimeSeconds,
    required this.feedback,
    required this.active,
    required this.accent,
    required this.gridColor,
  });

  final double delayTimeSeconds;
  final double feedback;
  final bool active;
  final Color accent;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.68;
    final timeRatio =
        math.log(
          delayTimeSeconds.clamp(
                minimumDelayTimeSeconds,
                maximumSynchronizedDelayTimeSeconds,
              ) /
              minimumDelayTimeSeconds,
        ) /
        math.log(maximumSynchronizedDelayTimeSeconds / minimumDelayTimeSeconds);
    final spacing = 25 + 48 * timeRatio;
    final repeatCount = math.min(5, ((size.width - 30) / spacing).floor() + 1);
    final paintColor = active ? accent : gridColor.withValues(alpha: 0.65);
    canvas.drawLine(
      Offset(16, baseline),
      Offset(size.width - 16, baseline),
      Paint()
        ..color = gridColor.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    for (var index = 0; index < repeatCount; index++) {
      final amplitude = index == 0
          ? 1.0
          : math.pow(clampDelayFeedback(feedback), index).toDouble();
      final x = 20 + spacing * index;
      final height = 8 + 35 * amplitude;
      canvas.drawLine(
        Offset(x, baseline),
        Offset(x, baseline - height),
        Paint()
          ..color = paintColor.withValues(alpha: 0.3 + 0.7 * amplitude)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, baseline - height),
        3.2,
        Paint()..color = paintColor.withValues(alpha: 0.35 + 0.65 * amplitude),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DelayRepeatsPainter oldDelegate) =>
      oldDelegate.delayTimeSeconds != delayTimeSeconds ||
      oldDelegate.feedback != feedback ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent ||
      oldDelegate.gridColor != gridColor;
}

class _FxChainSlots extends StatelessWidget {
  const _FxChainSlots({
    required this.order,
    required this.selected,
    required this.filterActive,
    required this.eqActive,
    required this.compressorActive,
    required this.delayActive,
    required this.accent,
    required this.onSelected,
    required this.onReorder,
  });

  final List<TrackFxType> order;
  final TrackFxType selected;
  final bool filterActive;
  final bool eqActive;
  final bool compressorActive;
  final bool delayActive;
  final Color accent;
  final ValueChanged<TrackFxType> onSelected;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
            child: Text(
              'SIGNAL FLOW  -  TOP TO BOTTOM',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.05,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ReorderableListView.builder(
            key: const ValueKey('track-fx-chain'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: order.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: Colors.black54,
              child: child,
            ),
            itemBuilder: (context, index) {
              final effect = order[index];
              final active = switch (effect) {
                TrackFxType.filter => filterActive,
                TrackFxType.eq => eqActive,
                TrackFxType.compressor => compressorActive,
                TrackFxType.delay => delayActive,
              };
              final effectAccent = switch (effect) {
                TrackFxType.filter => accent,
                TrackFxType.eq => const Color(0xFF79B8FF),
                TrackFxType.compressor => const Color(0xFFFFB45E),
                TrackFxType.delay => const Color(0xFF7CD7C4),
              };
              return Padding(
                key: ValueKey('track-fx-slot-${effect.name}'),
                padding: const EdgeInsets.only(bottom: 3),
                child: _FxSlotRow(
                  effect: effect,
                  index: index,
                  slotCount: order.length,
                  selected: selected == effect,
                  active: active,
                  accent: effectAccent,
                  onTap: () => onSelected(effect),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FxSlotRow extends StatelessWidget {
  const _FxSlotRow({
    required this.effect,
    required this.index,
    required this.slotCount,
    required this.selected,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final TrackFxType effect;
  final int index;
  final int slotCount;
  final bool selected;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = effect.displayName;
    return Semantics(
      label:
          '$label, effect slot ${index + 1} of $slotCount, '
          '${active ? 'enabled' : 'bypassed'}',
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('track-fx-${effect.name}-tab'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 34,
            padding: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(
                      accent.withValues(alpha: 0.1),
                      scheme.surfaceContainerHighest,
                    )
                  : scheme.surface.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.68)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                DawInteractionHint(
                  data: DawInteractionHints.fxReorder,
                  child: Semantics(
                    label: 'Reorder $label effect',
                    child: ReorderableDragStartListener(
                      key: ValueKey('track-fx-reorder-${effect.name}'),
                      index: index,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: SizedBox(
                          width: 30,
                          height: 34,
                          child: Icon(
                            Icons.drag_indicator,
                            size: 17,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.76,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: scheme.outlineVariant),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.75,
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : scheme.onSurfaceVariant.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: active
                        ? null
                        : Border.all(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  active ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: active ? accent : scheme.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectHeader extends StatelessWidget {
  const _EffectHeader({
    required this.title,
    required this.enabled,
    required this.accent,
    required this.toggleKey,
    required this.onToggle,
    this.onReset,
    this.resetKey,
  });

  final String title;
  final bool enabled;
  final Color accent;
  final Key toggleKey;
  final VoidCallback onToggle;
  final VoidCallback? onReset;
  final Key? resetKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (onReset != null)
            TextButton(
              key: resetKey ?? const ValueKey('track-eq-reset'),
              onPressed: onReset,
              style: TextButton.styleFrom(
                minimumSize: const Size(42, 24),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Reset', style: TextStyle(fontSize: 10)),
            ),
          if (onReset != null) const SizedBox(width: 5),
          _CompactPowerButton(
            key: toggleKey,
            label: enabled ? 'ON' : 'OFF',
            enabled: enabled,
            accent: accent,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _FilterModulePanel extends StatelessWidget {
  const _FilterModulePanel({
    required this.title,
    required this.enabled,
    required this.globallyEnabled,
    required this.accent,
    required this.frequencyHz,
    required this.q,
    required this.frequencyParameter,
    required this.qParameter,
    required this.onToggle,
    required this.onBegin,
    required this.onPreview,
    required this.onCommit,
    required this.onReset,
  });

  final String title;
  final bool enabled;
  final bool globallyEnabled;
  final Color accent;
  final double frequencyHz;
  final double q;
  final TrackFilterParameter frequencyParameter;
  final TrackFilterParameter qParameter;
  final VoidCallback onToggle;
  final ValueChanged<TrackFilterParameter> onBegin;
  final void Function(TrackFilterParameter, double) onPreview;
  final void Function(TrackFilterParameter, double) onCommit;
  final ValueChanged<TrackFilterParameter> onReset;

  @override
  Widget build(BuildContext context) {
    final active = enabled && globallyEnabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: active ? 1 : 0.58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _CompactPowerButton(
                  key: ValueKey('${title.toLowerCase()}-toggle'),
                  label: enabled ? 'ON' : 'OFF',
                  enabled: enabled,
                  accent: accent,
                  onPressed: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RotaryKnob(
                  key: ValueKey('$frequencyParameter-knob'),
                  label: 'CUTOFF',
                  semanticLabel: '$title cutoff',
                  value: frequencyHz,
                  minimum: minimumFilterFrequencyHz,
                  maximum: maximumFilterFrequencyHz,
                  logarithmic: true,
                  valueLabel: formatFilterFrequency(frequencyHz),
                  valueFormatter: formatFilterFrequency,
                  active: active,
                  accent: accent,
                  onChangeStart: () => onBegin(frequencyParameter),
                  onChanged: (value) => onPreview(frequencyParameter, value),
                  onChangeEnd: (value) => onCommit(frequencyParameter, value),
                  onReset: () => onReset(frequencyParameter),
                ),
                _RotaryKnob(
                  key: ValueKey('$qParameter-knob'),
                  label: 'RES',
                  semanticLabel: '$title resonance',
                  value: q,
                  minimum: minimumFilterQ,
                  maximum: maximumFilterQ,
                  logarithmic: false,
                  valueLabel: 'Q ${q.toStringAsFixed(2)}',
                  valueFormatter: (value) => 'Q ${value.toStringAsFixed(2)}',
                  active: active,
                  accent: accent,
                  onChangeStart: () => onBegin(qParameter),
                  onChanged: (value) => onPreview(qParameter, value),
                  onChangeEnd: (value) => onCommit(qParameter, value),
                  onReset: () => onReset(qParameter),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPowerButton extends StatelessWidget {
  const _CompactPowerButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: enabled ? 'Bypass' : 'Enable',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 24,
          constraints: const BoxConstraints(minWidth: 42),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.85) : scheme.outline,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: enabled ? accent : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotaryKnob extends StatefulWidget {
  const _RotaryKnob({
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

  @override
  State<_RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<_RotaryKnob> {
  late double _normalized;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _normalized = _normalize(widget.value);
  }

  @override
  void didUpdateWidget(covariant _RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) {
      _normalized = _normalize(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DawInteractionHint(
      data: DawInteractionHints.rotaryKnob,
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
            },
            onVerticalDragEnd: (_) {
              _dragging = false;
              widget.onChangeEnd(_denormalize(_normalized));
            },
            onVerticalDragCancel: () {
              _dragging = false;
              widget.onChangeEnd(_denormalize(_normalized));
            },
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
                    painter: _KnobPainter(
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

class _KnobPainter extends CustomPainter {
  const _KnobPainter({
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
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.normalized != normalized ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent ||
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.inactiveColor != inactiveColor;
}

class _FilterResponsePainter extends CustomPainter {
  const _FilterResponsePainter({
    required this.filter,
    required this.accent,
    required this.gridColor,
    required this.labelColor,
  });

  final TrackFilterFx filter;
  final Color accent;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 22.0;
    final graph = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (final db in const [-24.0, -12.0, 0.0]) {
      final y = _dbY(db, graph);
      canvas.drawLine(Offset(graph.left, y), Offset(graph.right, y), gridPaint);
    }
    for (final frequency in const [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
      final x = _frequencyX(frequency, graph);
      canvas.drawLine(Offset(x, graph.top), Offset(x, graph.bottom), gridPaint);
      final label = switch (frequency) {
        20 => '20',
        100 => '100',
        1000 => '1k',
        10000 => '10k',
        _ => '20k',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          graph.bottom + 5,
        ),
      );
    }

    final active =
        filter.enabled && (filter.highPass.enabled || filter.lowPass.enabled);
    final path = Path();
    const pointCount = 180;
    for (var index = 0; index < pointCount; index++) {
      final ratio = index / (pointCount - 1);
      final frequency =
          minimumFilterFrequencyHz *
          math.pow(maximumFilterFrequencyHz / minimumFilterFrequencyHz, ratio);
      var magnitude = 1.0;
      if (filter.enabled && filter.highPass.enabled) {
        magnitude *= _biquadMagnitude(
          frequency: frequency.toDouble(),
          cutoff: filter.highPass.frequencyHz,
          q: filter.highPass.q,
          highPass: true,
        );
      }
      if (filter.enabled && filter.lowPass.enabled) {
        magnitude *= _biquadMagnitude(
          frequency: frequency.toDouble(),
          cutoff: filter.lowPass.frequencyHz,
          q: filter.lowPass.q,
          highPass: false,
        );
      }
      final db = 20 * math.log(math.max(magnitude, 0.000001)) / math.ln10;
      final point = Offset(
        graph.left + graph.width * ratio,
        _dbY(db.clamp(-36.0, 12.0), graph),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = active ? accent : labelColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _frequencyX(double frequency, Rect graph) {
    final ratio =
        math.log(frequency / minimumFilterFrequencyHz) /
        math.log(maximumFilterFrequencyHz / minimumFilterFrequencyHz);
    return graph.left + graph.width * ratio;
  }

  double _dbY(double db, Rect graph) =>
      graph.top + graph.height * ((12 - db) / 48);

  double _biquadMagnitude({
    required double frequency,
    required double cutoff,
    required double q,
    required bool highPass,
  }) {
    const sampleRate = 48000.0;
    final omega0 = 2 * math.pi * cutoff / sampleRate;
    final cosine0 = math.cos(omega0);
    final alpha = math.sin(omega0) / (2 * q);
    final a0 = 1 + alpha;
    final a1 = -2 * cosine0 / a0;
    final a2 = (1 - alpha) / a0;
    final scale = highPass ? 1 + cosine0 : 1 - cosine0;
    final b0 = scale / 2 / a0;
    final b1 = (highPass ? -scale : scale) / a0;
    final b2 = b0;
    final omega = 2 * math.pi * frequency / sampleRate;
    final cosine = math.cos(omega);
    final sine = math.sin(omega);
    final cosine2 = math.cos(2 * omega);
    final sine2 = math.sin(2 * omega);
    final numeratorReal = b0 + b1 * cosine + b2 * cosine2;
    final numeratorImaginary = -b1 * sine - b2 * sine2;
    final denominatorReal = 1 + a1 * cosine + a2 * cosine2;
    final denominatorImaginary = -a1 * sine - a2 * sine2;
    return math.sqrt(
      (numeratorReal * numeratorReal +
              numeratorImaginary * numeratorImaginary) /
          (denominatorReal * denominatorReal +
              denominatorImaginary * denominatorImaginary),
    );
  }

  @override
  bool shouldRepaint(covariant _FilterResponsePainter oldDelegate) =>
      oldDelegate.filter != filter ||
      oldDelegate.accent != accent ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}

enum _EqBand { low, mid, high }

class _EqResponsePainter extends CustomPainter {
  const _EqResponsePainter({
    required this.eq,
    required this.gridColor,
    required this.labelColor,
  });

  final TrackEqFx eq;
  final Color gridColor;
  final Color labelColor;

  static const _lowColor = Color(0xFF64C7D0);
  static const _midColor = Color(0xFFE4B85D);
  static const _highColor = Color(0xFFC28BE8);
  static const _combinedColor = Color(0xFF9FCBFF);

  @override
  void paint(Canvas canvas, Size size) {
    const graph = EdgeInsets.fromLTRB(24, 8, 8, 22);
    final rect = Rect.fromLTRB(
      graph.left,
      graph.top,
      size.width - graph.right,
      size.height - graph.bottom,
    );
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (final db in const [-18.0, 0.0, 18.0]) {
      final y = _dbY(db, rect);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      _paintLabel(canvas, '${db.toInt()}', Offset(2, y - 5));
    }
    for (final frequency in const [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
      final x = _frequencyX(frequency, rect);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
      final label = switch (frequency) {
        20 => '20',
        100 => '100',
        1000 => '1k',
        10000 => '10k',
        _ => '20k',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          rect.bottom + 5,
        ),
      );
    }

    if (eq.enabled) {
      _drawBand(canvas, rect, _EqBand.low, _lowColor);
      _drawBand(canvas, rect, _EqBand.mid, _midColor);
      _drawBand(canvas, rect, _EqBand.high, _highColor);
    }
    final combined = _responsePath(rect, null);
    canvas.drawPath(
      combined,
      Paint()
        ..color = eq.enabled
            ? _combinedColor
            : labelColor.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = eq.enabled ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (eq.enabled) {
      _drawHandle(canvas, rect, defaultEqLowFrequencyHz, _lowColor);
      _drawHandle(canvas, rect, eq.midFrequencyHz, _midColor);
      _drawHandle(canvas, rect, defaultEqHighFrequencyHz, _highColor);
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawBand(Canvas canvas, Rect rect, _EqBand band, Color color) {
    canvas.drawPath(
      _responsePath(rect, band),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawHandle(Canvas canvas, Rect rect, double frequency, Color color) {
    final x = _frequencyX(frequency, rect);
    final db = _combinedDb(frequency).clamp(-18.0, 18.0);
    final center = Offset(x, _dbY(db, rect));
    canvas.drawCircle(center, 4.2, Paint()..color = const Color(0xFF11151A));
    canvas.drawCircle(
      center,
      4.2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  Path _responsePath(Rect rect, _EqBand? band) {
    final path = Path();
    const count = 240;
    for (var index = 0; index < count; index++) {
      final ratio = index / (count - 1);
      final frequency = 20 * math.pow(1000, ratio).toDouble();
      final db =
          (band == null ? _combinedDb(frequency) : _bandDb(frequency, band))
              .clamp(-18.0, 18.0);
      final point = Offset(rect.left + rect.width * ratio, _dbY(db, rect));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  double _combinedDb(double frequency) {
    if (!eq.enabled) return 0;
    return _bandDb(frequency, _EqBand.low) +
        _bandDb(frequency, _EqBand.mid) +
        _bandDb(frequency, _EqBand.high);
  }

  double _bandDb(double frequency, _EqBand band) {
    final magnitude = switch (band) {
      _EqBand.low => _eqMagnitude(
        band: band,
        frequency: frequency,
        centerFrequency: defaultEqLowFrequencyHz,
        gainDb: eq.lowGainDb,
        q: 1,
      ),
      _EqBand.mid => _eqMagnitude(
        band: band,
        frequency: frequency,
        centerFrequency: eq.midFrequencyHz,
        gainDb: eq.midGainDb,
        q: eq.midQ,
      ),
      _EqBand.high => _eqMagnitude(
        band: band,
        frequency: frequency,
        centerFrequency: defaultEqHighFrequencyHz,
        gainDb: eq.highGainDb,
        q: 1,
      ),
    };
    return 20 * math.log(math.max(magnitude, 0.000001)) / math.ln10;
  }

  double _frequencyX(double frequency, Rect rect) =>
      rect.left + rect.width * math.log(frequency / 20) / math.log(1000);

  double _dbY(double db, Rect rect) =>
      rect.top + rect.height * ((18 - db) / 36);

  double _eqMagnitude({
    required _EqBand band,
    required double frequency,
    required double centerFrequency,
    required double gainDb,
    required double q,
  }) {
    const sampleRate = 48000.0;
    final a = math.pow(10, gainDb / 40).toDouble();
    final omega0 = 2 * math.pi * centerFrequency / sampleRate;
    final cosine0 = math.cos(omega0);
    final sine0 = math.sin(omega0);
    late final double b0;
    late final double b1;
    late final double b2;
    late final double a0;
    late final double a1;
    late final double a2;
    if (band == _EqBand.mid) {
      final alpha = sine0 / (2 * q);
      b0 = 1 + alpha * a;
      b1 = -2 * cosine0;
      b2 = 1 - alpha * a;
      a0 = 1 + alpha / a;
      a1 = -2 * cosine0;
      a2 = 1 - alpha / a;
    } else {
      final alpha = sine0 / 2 * math.sqrt(2);
      final shelfTerm = 2 * math.sqrt(a) * alpha;
      if (band == _EqBand.low) {
        b0 = a * ((a + 1) - (a - 1) * cosine0 + shelfTerm);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosine0);
        b2 = a * ((a + 1) - (a - 1) * cosine0 - shelfTerm);
        a0 = (a + 1) + (a - 1) * cosine0 + shelfTerm;
        a1 = -2 * ((a - 1) + (a + 1) * cosine0);
        a2 = (a + 1) + (a - 1) * cosine0 - shelfTerm;
      } else {
        b0 = a * ((a + 1) + (a - 1) * cosine0 + shelfTerm);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosine0);
        b2 = a * ((a + 1) + (a - 1) * cosine0 - shelfTerm);
        a0 = (a + 1) - (a - 1) * cosine0 + shelfTerm;
        a1 = 2 * ((a - 1) - (a + 1) * cosine0);
        a2 = (a + 1) - (a - 1) * cosine0 - shelfTerm;
      }
    }
    final omega = 2 * math.pi * frequency / sampleRate;
    final cosine = math.cos(omega);
    final sine = math.sin(omega);
    final cosine2 = math.cos(2 * omega);
    final sine2 = math.sin(2 * omega);
    final numeratorReal = b0 + b1 * cosine + b2 * cosine2;
    final numeratorImaginary = -b1 * sine - b2 * sine2;
    final denominatorReal = a0 + a1 * cosine + a2 * cosine2;
    final denominatorImaginary = -a1 * sine - a2 * sine2;
    return math.sqrt(
      (numeratorReal * numeratorReal +
              numeratorImaginary * numeratorImaginary) /
          (denominatorReal * denominatorReal +
              denominatorImaginary * denominatorImaginary),
    );
  }

  @override
  bool shouldRepaint(covariant _EqResponsePainter oldDelegate) =>
      oldDelegate.eq != eq ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
