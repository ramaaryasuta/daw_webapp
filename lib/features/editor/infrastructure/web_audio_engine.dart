import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/audio_clip.dart';
import '../domain/audio_meter.dart';
import '../domain/daw_track.dart';
import '../domain/loop_region.dart';
import '../domain/master_limiter.dart';
import '../domain/musical_timing.dart';
import '../domain/track_mixer.dart';
import '../domain/track_filter_fx.dart';
import '../domain/track_eq_fx.dart';
import '../domain/track_compressor_fx.dart';
import '../domain/track_delay_fx.dart';
import '../domain/track_reverb_fx.dart';
import '../domain/track_fx_chain.dart';
import 'reverb_impulse_buffer_web.dart';
import 'web_metronome_scheduler.dart';

class DecodedAudioInfo {
  const DecodedAudioInfo({
    required this.durationSeconds,
    required this.sampleRate,
    required this.numberOfChannels,
    required this.waveformPeaks,
  });

  final double durationSeconds;
  final double sampleRate;
  final int numberOfChannels;

  final List<double> waveformPeaks;
}

/// A fully decoded, not-yet-committed set of project audio sources.
///
/// Browser AudioBuffers remain infrastructure-owned and never enter Riverpod
/// state. Building this staging object lets Open validate and decode every
/// source before replacing the active project.
class PreparedAudioSources {
  PreparedAudioSources._(this._buffers, this.infoByAssetId);

  final Map<String, web.AudioBuffer> _buffers;
  final Map<String, DecodedAudioInfo> infoByAssetId;
}

class WebAudioEngine implements AudioMeterPeakSource {
  WebAudioEngine() : _audioContext = web.AudioContext() {
    _masterMix = _audioContext.createGain();
    _masterGain = _audioContext.createGain();
    _masterGain.gain.value = masterDbToLinearGain(_masterVolumeDb);
    _masterLimiter = _MasterLimiterRuntime.create(
      _audioContext,
      _masterLimiterSettings,
    );
    _masterMix.connect(_masterGain);
    _masterGain.connect(_masterLimiter.input);
    _masterLimiter.output.connect(_audioContext.destination);
    _masterMeterTap = _StereoMeterTap.create(
      _audioContext,
      _masterLimiter.output,
    );
    _metronomeScheduler = WebMetronomeScheduler(_audioContext, _masterMix);
  }

  final web.AudioContext _audioContext;
  late final web.GainNode _masterMix;
  late final web.GainNode _masterGain;
  late final _MasterLimiterRuntime _masterLimiter;
  late final _StereoMeterTap _masterMeterTap;
  late final WebMetronomeScheduler _metronomeScheduler;

  final Map<String, web.AudioBuffer> _buffers = {};
  final Map<String, web.AudioBuffer> _reversedBuffers = {};

  final Map<String, List<_ScheduledSource>> _activeSources = {};

  final Map<String, web.GainNode> _trackGains = {};
  final Map<String, web.StereoPannerNode> _trackPanners = {};
  final Map<String, _StereoMeterTap> _trackMeterTaps = {};
  final Map<String, _TrackFilterRuntime> _trackFilters = {};
  final Map<String, _TrackEqRuntime> _trackEqs = {};
  final Map<String, _TrackCompressorRuntime> _trackCompressors = {};
  final Map<String, _TrackDelayRuntime> _trackDelays = {};
  final Map<String, _TrackReverbRuntime> _trackReverbs = {};
  final Map<int, web.AudioBuffer> _reverbIrCache = {};
  final Map<String, web.GainNode> _trackFxInputs = {};
  final Map<String, List<TrackFxType>> _trackFxOrders = {};

  bool _isPlaying = false;
  double _masterVolumeDb = unityMasterVolumeDb;
  MasterLimiterSettings _masterLimiterSettings = const MasterLimiterSettings();
  int _playRequestId = 0;

  double _timelineStartSeconds = 0;
  double _contextStartTime = 0;

  double _projectDurationSeconds = 0;
  double _tempoBpm = 120;

  LoopRegion? _activeLoopRegion;
  List<DawTrack> _scheduledTracks = const [];
  Timer? _loopLookAheadTimer;
  double _nextLoopContextTime = 0;

  static const double _mixerRampSeconds = 0.008;
  static const Duration _loopSchedulerInterval = Duration(milliseconds: 25);
  static const double _loopLookAheadSeconds = 0.2;
  static const double _minimumScheduleLeadSeconds = 0.005;

  bool get isPlaying => _isPlaying;

  double get sampleRate => _audioContext.sampleRate;

  double get masterVolumeDb => _masterVolumeDb;

  MasterLimiterSettings get masterLimiterSettings => _masterLimiterSettings;

  double get tempoBpm => _tempoBpm;

  void setMasterVolumeDb(double volumeDb) {
    _masterVolumeDb = clampMasterVolumeDb(volumeDb);
    _smoothGainTo(_masterGain, masterDbToLinearGain(_masterVolumeDb));
  }

  void setMasterLimiter(MasterLimiterSettings settings) {
    _masterLimiterSettings = settings.clamped();
    _masterLimiter.update(_masterLimiterSettings, this);
  }

  @override
  MeterPeaksSnapshot readMeterPeaks() {
    return MeterPeaksSnapshot(
      tracks: {
        for (final entry in _trackMeterTaps.entries)
          entry.key: entry.value.readPeak(),
      },
      master: _masterMeterTap.readPeak(),
      masterLimiterReductionDb: _masterLimiter.reductionDb,
      compressorReductionDb: {
        for (final entry in _trackCompressors.entries)
          entry.key: entry.value.reductionDb,
      },
    );
  }

  web.AudioBuffer? decodedBufferForAsset(String assetId) {
    return _buffers[assetId];
  }

  /// Returns the reusable playback buffer appropriate for [clip].
  ///
  /// A reversed representation is built at most once per source asset and is
  /// deliberately kept out of editor/project state.
  web.AudioBuffer? playbackBufferForClip(AudioClip clip) {
    final original = _buffers[clip.audio.id];
    if (original == null || !clip.isReversed) {
      return original;
    }
    return _reversedBuffers.putIfAbsent(
      clip.audio.id,
      () => _createReversedBuffer(original),
    );
  }

  double get currentPositionSeconds {
    if (!_isPlaying) {
      return _timelineStartSeconds;
    }

    final elapsed = _audioContext.currentTime - _contextStartTime;

    if (elapsed <= 0) {
      return _timelineStartSeconds;
    }

    final position = _timelineStartSeconds + elapsed;
    final loop = _activeLoopRegion;
    if (loop != null && position >= loop.endSeconds) {
      return loop.startSeconds +
          ((position - loop.endSeconds) % loop.durationSeconds);
    }

    return position.clamp(0.0, _transportEndSeconds);
  }

  double get _transportEndSeconds =>
      math.max(_projectDurationSeconds, _activeLoopRegion?.endSeconds ?? 0);

  Future<DecodedAudioInfo> decode({
    required String assetId,
    required Uint8List bytes,
  }) async {
    final decoded = await _decodeSource(bytes);
    _buffers[assetId] = decoded.buffer;
    _reversedBuffers.remove(assetId);
    return decoded.info;
  }

  Future<PreparedAudioSources> prepareAudioSources(
    Map<String, Uint8List> bytesByAssetId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final buffers = <String, web.AudioBuffer>{};
    final info = <String, DecodedAudioInfo>{};
    var completed = 0;
    for (final entry in bytesByAssetId.entries) {
      final decoded = await _decodeSource(entry.value);
      buffers[entry.key] = decoded.buffer;
      info[entry.key] = decoded.info;
      completed++;
      onProgress?.call(completed, bytesByAssetId.length);
    }
    return PreparedAudioSources._(
      Map.unmodifiable(buffers),
      Map.unmodifiable(info),
    );
  }

  void commitPreparedAudioSources(PreparedAudioSources prepared) {
    _playRequestId++;
    stopSources();
    _timelineStartSeconds = 0;
    _projectDurationSeconds = 0;
    _activeLoopRegion = null;
    _isPlaying = false;
    _buffers
      ..clear()
      ..addAll(prepared._buffers);
    _reversedBuffers.clear();
    _disposeAllTrackMixerNodes();
  }

  Future<({web.AudioBuffer buffer, DecodedAudioInfo info})> _decodeSource(
    Uint8List bytes,
  ) async {
    final byteBuffer = Uint8List.fromList(bytes).buffer;

    final audioBuffer = await _audioContext
        .decodeAudioData(byteBuffer.toJS)
        .toDart;

    final waveformPeaks = _extractWaveformPeaks(audioBuffer);

    return (
      buffer: audioBuffer,
      info: DecodedAudioInfo(
        durationSeconds: audioBuffer.duration,
        sampleRate: audioBuffer.sampleRate,
        numberOfChannels: audioBuffer.numberOfChannels,
        waveformPeaks: waveformPeaks,
      ),
    );
  }

  Future<void> play({
    required List<DawTrack> tracks,
    required double fromSeconds,
    LoopRegion? loopRegion,
  }) async {
    final projectDuration = calculateProjectRenderDurationSeconds(
      tracks,
      bpm: _tempoBpm,
    );
    if (projectDuration <= 0 && loopRegion == null) {
      return;
    }

    final requestId = ++_playRequestId;

    stopSources();

    // Browser bisa memulai AudioContext dalam keadaan
    // suspended karena autoplay policy.
    await _audioContext.resume().toDart;

    if (requestId != _playRequestId) {
      return;
    }

    _projectDurationSeconds = projectDuration;
    _activeLoopRegion = loopRegion;
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);

    if (loopRegion != null && !loopRegion.contains(fromSeconds)) {
      fromSeconds = loopRegion.startSeconds;
    } else if (loopRegion == null && fromSeconds >= _projectDurationSeconds) {
      fromSeconds = 0;
    }

    _timelineStartSeconds = fromSeconds;

    // Berikan sedikit lead time.
    //
    // Semua node kemudian dijadwalkan terhadap
    // clock yang sama.
    final startAt = _audioContext.currentTime + 0.03;

    _contextStartTime = startAt;

    _syncTrackMixerNodes(tracks);

    if (loopRegion == null) {
      _scheduleSegment(
        tracks: tracks,
        timelineStartSeconds: fromSeconds,
        timelineEndSeconds: _projectDurationSeconds,
        contextStartTime: startAt,
      );
    } else {
      _scheduleSegment(
        tracks: tracks,
        timelineStartSeconds: fromSeconds,
        timelineEndSeconds: loopRegion.endSeconds,
        contextStartTime: startAt,
      );
      _nextLoopContextTime = startAt + (loopRegion.endSeconds - fromSeconds);
      _scheduleLoopLookAhead();
      _loopLookAheadTimer = Timer.periodic(
        _loopSchedulerInterval,
        (_) => _scheduleLoopLookAhead(),
      );
    }

    _metronomeScheduler.startTransport(
      timelineStartSeconds: _timelineStartSeconds,
      contextStartTime: _contextStartTime,
      loopRegion: loopRegion,
    );
    _isPlaying = true;
  }

  void _syncTrackMixerNodes(List<DawTrack> tracks) {
    final hasSolo = tracks.any((track) => track.isSolo);
    final trackIds = tracks.map((track) => track.id).toSet();
    for (final trackId in _trackGains.keys.toList()) {
      if (!trackIds.contains(trackId)) {
        removeTrack(trackId);
      }
    }

    for (final track in tracks) {
      final existingGain = _trackGains[track.id];
      if (existingGain != null) {
        _smoothGainTo(
          existingGain,
          effectiveTrackGain(track, hasSolo: hasSolo),
        );
        _smoothAudioParamTo(
          _trackPanners[track.id]!.pan,
          clampTrackPan(track.pan),
        );
        _trackFilters[track.id]!.update(track.filterFx, this);
        _trackEqs[track.id]!.update(track.eqFx, this);
        _trackCompressors[track.id]!.update(track.compressorFx, this);
        _trackDelays[track.id]!.update(track.delayFx, _tempoBpm, this);
        _trackReverbs[track.id]!.update(track.reverbFx, this);
        _rebuildTrackFxRoutingIfNeeded(track);
        continue;
      }

      final fxInput = _audioContext.createGain();
      final filter = _TrackFilterRuntime.create(_audioContext, track.filterFx);
      final eq = _TrackEqRuntime.create(_audioContext, track.eqFx);
      final compressor = _TrackCompressorRuntime.create(
        _audioContext,
        track.compressorFx,
      );
      final delay = _TrackDelayRuntime.create(
        _audioContext,
        track.delayFx,
        _tempoBpm,
      );
      final reverb = _TrackReverbRuntime.create(
        _audioContext,
        track.reverbFx,
        this,
      );
      final gain = _audioContext.createGain();
      final panner = _audioContext.createStereoPanner();
      gain.gain.value = effectiveTrackGain(track, hasSolo: hasSolo);
      panner.pan.value = clampTrackPan(track.pan);
      gain.connect(panner);
      panner.connect(_masterMix);
      _trackFxInputs[track.id] = fxInput;
      _trackFilters[track.id] = filter;
      _trackEqs[track.id] = eq;
      _trackCompressors[track.id] = compressor;
      _trackDelays[track.id] = delay;
      _trackReverbs[track.id] = reverb;
      _trackGains[track.id] = gain;
      _trackPanners[track.id] = panner;
      _trackMeterTaps[track.id] = _StereoMeterTap.create(_audioContext, panner);
      _rebuildTrackFxRouting(track.id, track.fxChainOrder);
    }
  }

  void _scheduleSegment({
    required List<DawTrack> tracks,
    required double timelineStartSeconds,
    required double timelineEndSeconds,
    required double contextStartTime,
  }) {
    if (timelineEndSeconds <= timelineStartSeconds) {
      return;
    }

    for (final track in tracks) {
      final fxInput = _trackFxInputs[track.id];
      if (fxInput == null) {
        continue;
      }
      for (final clip in track.clips) {
        final buffer = playbackBufferForClip(clip);
        if (buffer == null) {
          continue;
        }

        final playbackTiming = clip.playbackTimingFrom(timelineStartSeconds);

        // Clip sudah habis sebelum posisi playhead.
        if (playbackTiming == null ||
            playbackTiming.bufferOffsetSeconds >= buffer.duration) {
          continue;
        }

        final scheduledTimelineStart =
            timelineStartSeconds + playbackTiming.delaySeconds;
        final availableSegmentDuration =
            timelineEndSeconds - scheduledTimelineStart;
        final availableBufferDuration =
            buffer.duration - playbackTiming.bufferOffsetSeconds;
        final playbackDuration = math.min(
          playbackTiming.playbackDurationSeconds,
          math.min(availableSegmentDuration, availableBufferDuration),
        );
        if (playbackDuration <= 0) {
          continue;
        }

        final source = _audioContext.createBufferSource();
        final fadeGain = _audioContext.createGain();
        final clipGain = _audioContext.createGain();
        source.buffer = buffer;
        source.connect(fadeGain);
        fadeGain.connect(clipGain);
        clipGain.connect(fxInput);
        clipGain.gain.value = clipGainDbToLinear(clip.gainDb);
        final sourceStartTime = contextStartTime + playbackTiming.delaySeconds;
        final clipLocalStartSeconds =
            scheduledTimelineStart - clip.timelineStartSeconds;
        _scheduleClipFadeEnvelope(
          fadeGain.gain,
          clip: clip,
          clipLocalStartSeconds: clipLocalStartSeconds,
          playbackDurationSeconds: playbackDuration,
          sourceStartTime: sourceStartTime,
        );
        final scheduledSource = _ScheduledSource(
          node: source,
          clipId: clip.id,
          fadeGain: fadeGain,
          clipGain: clipGain,
          endTime: sourceStartTime + playbackDuration,
        );
        _activeSources.putIfAbsent(track.id, () => []).add(scheduledSource);
        source.start(
          sourceStartTime,
          playbackTiming.bufferOffsetSeconds,
          playbackDuration,
        );
      }
    }
  }

  void _scheduleLoopLookAhead() {
    final loop = _activeLoopRegion;
    if (loop == null || _contextStartTime == 0) {
      return;
    }

    final now = _audioContext.currentTime;
    _cleanUpFinishedSources(now);
    final windowEnd = now + _loopLookAheadSeconds;

    // Delay feedback remains continuous across loop wraps. The persistent
    // module and <= 0.90 feedback clamp make this bounded and predictable;
    // pause, stop, and seek clear its memory through [stopSources].
    while (_nextLoopContextTime <= windowEnd) {
      if (_nextLoopContextTime >= now + _minimumScheduleLeadSeconds) {
        _scheduleSegment(
          tracks: _scheduledTracks,
          timelineStartSeconds: loop.startSeconds,
          timelineEndSeconds: loop.endSeconds,
          contextStartTime: _nextLoopContextTime,
        );
      }
      _nextLoopContextTime += loop.durationSeconds;
    }
  }

  void _cleanUpFinishedSources(double currentTime) {
    for (final entry in _activeSources.entries.toList()) {
      final sources = entry.value;
      for (var index = sources.length - 1; index >= 0; index--) {
        final source = sources[index];
        if (source.endTime >= currentTime) {
          continue;
        }
        try {
          source.node.disconnect();
        } catch (_) {}
        try {
          source.fadeGain.disconnect();
          source.clipGain.disconnect();
        } catch (_) {}
        sources.removeAt(index);
      }
      if (sources.isEmpty) {
        _activeSources.remove(entry.key);
      }
    }
  }

  Future<void> seek({
    required List<DawTrack> tracks,
    required double positionSeconds,
    LoopRegion? loopRegion,
  }) async {
    _projectDurationSeconds = calculateProjectRenderDurationSeconds(
      tracks,
      bpm: _tempoBpm,
    );
    _activeLoopRegion = loopRegion;

    final transportEnd = math.max(
      _projectDurationSeconds,
      loopRegion?.endSeconds ?? 0,
    );
    final position = positionSeconds.clamp(0.0, transportEnd);
    final shouldResumePlayback =
        _isPlaying &&
        (loopRegion != null || position < _projectDurationSeconds);

    _playRequestId++;
    stopSources();
    _timelineStartSeconds = position;
    _isPlaying = false;

    if (shouldResumePlayback) {
      await play(tracks: tracks, fromSeconds: position, loopRegion: loopRegion);
    }
  }

  void pause() {
    _playRequestId++;

    if (!_isPlaying) {
      return;
    }

    final position = currentPositionSeconds;

    stopSources();

    _timelineStartSeconds = position;
    _isPlaying = false;
  }

  void stop() {
    _playRequestId++;
    stopSources();

    _timelineStartSeconds = 0;
    _isPlaying = false;
  }

  void stopSources() {
    _loopLookAheadTimer?.cancel();
    _loopLookAheadTimer = null;
    _metronomeScheduler.stopTransport();

    for (final sources in _activeSources.values) {
      for (final source in sources) {
        try {
          source.node.stop();
        } catch (_) {
          // Source mungkin sudah selesai.
        }

        try {
          source.node.disconnect();
        } catch (_) {}
        try {
          source.fadeGain.disconnect();
        } catch (_) {}
        try {
          source.clipGain.disconnect();
        } catch (_) {}
      }
    }

    _activeSources.clear();
    for (final delay in _trackDelays.values) {
      delay.resetTail();
    }
    for (final reverb in _trackReverbs.values) {
      reverb.resetTail();
    }
    _scheduledTracks = const [];
    _contextStartTime = 0;
  }

  void setTempoBpm(double tempoBpm) {
    if (!tempoBpm.isFinite || tempoBpm <= 0) return;
    _tempoBpm = tempoBpm;
    _metronomeScheduler.setTempoBpm(tempoBpm);
    for (final delay in _trackDelays.values) {
      delay.update(delay.settings, _tempoBpm, this);
    }
    if (_scheduledTracks.isNotEmpty) {
      _projectDurationSeconds = calculateProjectRenderDurationSeconds(
        _scheduledTracks,
        bpm: _tempoBpm,
      );
    }
  }

  void setTimeSignature(TimeSignature timeSignature) {
    _metronomeScheduler.setTimeSignature(timeSignature);
  }

  void setMetronomeEnabled(bool enabled) {
    _metronomeScheduler.setEnabled(enabled);
  }

  void syncMixer(List<DawTrack> tracks) {
    final hasSolo = tracks.any((track) => track.isSolo);

    for (final track in tracks) {
      final gain = _trackGains[track.id];
      final panner = _trackPanners[track.id];

      if (gain == null) {
        continue;
      }

      _smoothGainTo(gain, effectiveTrackGain(track, hasSolo: hasSolo));
      if (panner != null) {
        _smoothAudioParamTo(panner.pan, clampTrackPan(track.pan));
      }
      _trackFilters[track.id]?.update(track.filterFx, this);
      _trackEqs[track.id]?.update(track.eqFx, this);
      _trackCompressors[track.id]?.update(track.compressorFx, this);
      _trackDelays[track.id]?.update(track.delayFx, _tempoBpm, this);
      _trackReverbs[track.id]?.update(track.reverbFx, this);
      _rebuildTrackFxRoutingIfNeeded(track);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
  }

  void syncTrackFilterFx(List<DawTrack> tracks) {
    for (final track in tracks) {
      _trackFilters[track.id]?.update(track.filterFx, this);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
  }

  void syncTrackEqFx(List<DawTrack> tracks) {
    for (final track in tracks) {
      _trackEqs[track.id]?.update(track.eqFx, this);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
  }

  void syncTrackCompressorFx(List<DawTrack> tracks) {
    for (final track in tracks) {
      _trackCompressors[track.id]?.update(track.compressorFx, this);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
  }

  void syncTrackDelayFx(List<DawTrack> tracks) {
    for (final track in tracks) {
      _trackDelays[track.id]?.update(track.delayFx, _tempoBpm, this);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
    _projectDurationSeconds = calculateProjectRenderDurationSeconds(
      tracks,
      bpm: _tempoBpm,
    );
  }

  void syncTrackReverbFx(List<DawTrack> tracks) {
    for (final track in tracks) {
      _trackReverbs[track.id]?.update(track.reverbFx, this);
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
    _projectDurationSeconds = calculateProjectRenderDurationSeconds(
      tracks,
      bpm: _tempoBpm,
    );
  }

  void _rebuildTrackFxRoutingIfNeeded(DawTrack track) {
    final currentOrder = _trackFxOrders[track.id];
    if (currentOrder == null ||
        !hasSameTrackFxChainOrder(currentOrder, track.fxChainOrder)) {
      _rebuildTrackFxRouting(track.id, track.fxChainOrder);
    }
  }

  void _rebuildTrackFxRouting(String trackId, List<TrackFxType> order) {
    final fxInput = _trackFxInputs[trackId];
    final gain = _trackGains[trackId];
    final filter = _trackFilters[trackId];
    final eq = _trackEqs[trackId];
    final compressor = _trackCompressors[trackId];
    final delay = _trackDelays[trackId];
    final reverb = _trackReverbs[trackId];
    if (fxInput == null ||
        gain == null ||
        filter == null ||
        eq == null ||
        compressor == null ||
        delay == null ||
        reverb == null) {
      return;
    }

    final modules = <TrackFxType, _TrackFxRuntimeModule>{
      TrackFxType.filter: filter,
      TrackFxType.eq: eq,
      TrackFxType.compressor: compressor,
      TrackFxType.delay: delay,
      TrackFxType.reverb: reverb,
    };
    try {
      fxInput.disconnect();
    } catch (_) {}
    for (final module in modules.values) {
      try {
        module.output.disconnect();
      } catch (_) {}
    }

    web.AudioNode tail = fxInput;
    for (final effect in order) {
      final module = modules[effect]!;
      tail.connect(module.input);
      tail = module.output;
    }
    tail.connect(gain);
    _trackFxOrders[trackId] = List<TrackFxType>.unmodifiable(order);
  }

  void setClipGain(String clipId, double gainDb) {
    final clampedGainDb = clampClipGainDb(gainDb);
    final linearGain = clipGainDbToLinear(clampedGainDb);
    for (final sources in _activeSources.values) {
      for (final source in sources) {
        if (source.clipId == clipId) {
          _smoothGainTo(source.clipGain, linearGain);
        }
      }
    }
    _scheduledTracks = [
      for (final track in _scheduledTracks)
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              clip.id == clipId ? clip.copyWith(gainDb: clampedGainDb) : clip,
          ],
        ),
    ];
  }

  void syncClipGains(List<DawTrack> tracks) {
    final gainByClipId = {
      for (final track in tracks)
        for (final clip in track.clips) clip.id: clip.gainDb,
    };
    for (final entry in gainByClipId.entries) {
      final linearGain = clipGainDbToLinear(entry.value);
      for (final sources in _activeSources.values) {
        for (final source in sources) {
          if (source.clipId == entry.key) {
            _smoothGainTo(source.clipGain, linearGain);
          }
        }
      }
    }
    _scheduledTracks = List<DawTrack>.unmodifiable(tracks);
  }

  void _smoothGainTo(web.GainNode gainNode, double targetGain) {
    _smoothAudioParamTo(gainNode.gain, targetGain);
  }

  void _smoothAudioParamTo(web.AudioParam parameter, double targetValue) {
    final now = _audioContext.currentTime;
    try {
      parameter.cancelAndHoldAtTime(now);
    } catch (_) {
      parameter.cancelScheduledValues(now);
      parameter.setValueAtTime(parameter.value, now);
    }
    parameter.linearRampToValueAtTime(targetValue, now + _mixerRampSeconds);
  }

  web.AudioBuffer _reverbImpulseBuffer(double decaySeconds) {
    final key =
        (_audioContext.sampleRate * clampReverbDecaySeconds(decaySeconds))
            .ceil();
    final cached = _reverbIrCache.remove(key);
    if (cached != null) {
      _reverbIrCache[key] = cached;
      return cached;
    }
    final created = createReverbImpulseBuffer(
      _audioContext,
      decaySeconds: decaySeconds,
    );
    _reverbIrCache[key] = created;
    while (_reverbIrCache.length > 6) {
      _reverbIrCache.remove(_reverbIrCache.keys.first);
    }
    return created;
  }

  void removeTrack(String trackId) {
    final sources = _activeSources.remove(trackId);

    if (sources != null) {
      for (final source in sources) {
        try {
          source.node.stop();
          source.node.disconnect();
          source.fadeGain.disconnect();
          source.clipGain.disconnect();
        } catch (_) {}
      }
    }

    final gain = _trackGains.remove(trackId);
    final panner = _trackPanners.remove(trackId);
    final meterTap = _trackMeterTaps.remove(trackId);
    final filter = _trackFilters.remove(trackId);
    final eq = _trackEqs.remove(trackId);
    final compressor = _trackCompressors.remove(trackId);
    final delay = _trackDelays.remove(trackId);
    final reverb = _trackReverbs.remove(trackId);
    final fxInput = _trackFxInputs.remove(trackId);
    _trackFxOrders.remove(trackId);

    if (fxInput != null) {
      try {
        fxInput.disconnect();
      } catch (_) {}
    }

    if (gain != null) {
      try {
        gain.disconnect();
      } catch (_) {}
    }

    if (panner != null) {
      try {
        panner.disconnect();
      } catch (_) {}
    }

    meterTap?.dispose();
    filter?.dispose();
    eq?.dispose();
    compressor?.dispose();
    delay?.dispose();
    reverb?.dispose();
  }

  void _disposeAllTrackMixerNodes() {
    for (final meterTap in _trackMeterTaps.values) {
      meterTap.dispose();
    }
    for (final filter in _trackFilters.values) {
      filter.dispose();
    }
    for (final eq in _trackEqs.values) {
      eq.dispose();
    }
    for (final compressor in _trackCompressors.values) {
      compressor.dispose();
    }
    for (final delay in _trackDelays.values) {
      delay.dispose();
    }
    for (final reverb in _trackReverbs.values) {
      reverb.dispose();
    }
    for (final fxInput in _trackFxInputs.values) {
      try {
        fxInput.disconnect();
      } catch (_) {}
    }
    for (final gain in _trackGains.values) {
      try {
        gain.disconnect();
      } catch (_) {}
    }
    for (final panner in _trackPanners.values) {
      try {
        panner.disconnect();
      } catch (_) {}
    }
    _trackFilters.clear();
    _trackEqs.clear();
    _trackCompressors.clear();
    _trackDelays.clear();
    _trackReverbs.clear();
    _reverbIrCache.clear();
    _trackFxInputs.clear();
    _trackFxOrders.clear();
    _trackGains.clear();
    _trackPanners.clear();
    _trackMeterTaps.clear();
  }

  List<double> _extractWaveformPeaks(
    web.AudioBuffer buffer, {
    int targetPeakCount = 2000,
  }) {
    final frameCount = buffer.length;

    if (frameCount <= 0 || buffer.numberOfChannels <= 0) {
      return const [];
    }

    final peakCount = math.min(targetPeakCount, frameCount);

    final channels = <Float32List>[];

    for (var channel = 0; channel < buffer.numberOfChannels; channel++) {
      channels.add(buffer.getChannelData(channel).toDart);
    }

    final peaks = List<double>.filled(peakCount, 0, growable: false);

    for (var peakIndex = 0; peakIndex < peakCount; peakIndex++) {
      final start = (peakIndex * frameCount / peakCount).floor();
      final end = math.max(
        start + 1,
        ((peakIndex + 1) * frameCount / peakCount).floor(),
      );

      var maxAmplitude = 0.0;

      // Jangan scan ribuan sample untuk setiap peak.
      // Maksimal kira-kira 128 sample per bucket.
      final step = math.max(1, (end - start) ~/ 128);

      for (var sampleIndex = start; sampleIndex < end; sampleIndex += step) {
        for (final channel in channels) {
          final amplitude = channel[sampleIndex].abs();

          if (amplitude > maxAmplitude) {
            maxAmplitude = amplitude;
          }
        }
      }

      peaks[peakIndex] = maxAmplitude.clamp(0.0, 1.0);
    }

    return peaks;
  }

  web.AudioBuffer _createReversedBuffer(web.AudioBuffer original) {
    final reversed = _audioContext.createBuffer(
      original.numberOfChannels,
      original.length,
      original.sampleRate,
    );
    for (var channel = 0; channel < original.numberOfChannels; channel++) {
      final source = original.getChannelData(channel).toDart;
      final samples = Float32List(source.length);
      for (var index = 0; index < source.length; index++) {
        samples[index] = source[source.length - index - 1];
      }
      reversed.copyToChannel(samples.toJS, channel);
    }
    return reversed;
  }

  void _scheduleClipFadeEnvelope(
    web.AudioParam gain, {
    required AudioClip clip,
    required double clipLocalStartSeconds,
    required double playbackDurationSeconds,
    required double sourceStartTime,
  }) {
    final points = clipFadeEnvelopeForSegment(
      clip: clip,
      clipLocalStartSeconds: clipLocalStartSeconds,
      playbackDurationSeconds: playbackDurationSeconds,
    );
    gain.setValueAtTime(points.first.gain, sourceStartTime);
    for (final point in points.skip(1)) {
      gain.linearRampToValueAtTime(
        point.gain,
        sourceStartTime + point.offsetSeconds,
      );
    }
  }

  Future<void> dispose() async {
    _playRequestId++;
    stopSources();
    _disposeAllTrackMixerNodes();
    _metronomeScheduler.dispose();
    _masterMeterTap.dispose();
    try {
      _masterMix.disconnect();
    } catch (_) {}
    try {
      _masterGain.disconnect();
    } catch (_) {}
    _masterLimiter.dispose();
    _buffers.clear();
    _reversedBuffers.clear();

    await _audioContext.close().toDart;
  }
}

abstract interface class _TrackFxRuntimeModule {
  web.AudioNode get input;
  web.AudioNode get output;
}

class _TrackFilterRuntime implements _TrackFxRuntimeModule {
  _TrackFilterRuntime({
    required this.input,
    required this.output,
    required this.highPass,
    required this.lowPass,
    required this.highPassDry,
    required this.highPassWet,
    required this.lowPassDry,
    required this.lowPassWet,
    required this.globalDry,
    required this.globalWet,
    required this.nodes,
  });

  factory _TrackFilterRuntime.create(
    web.BaseAudioContext context,
    TrackFilterFx settings,
  ) {
    final input = context.createGain();
    final output = context.createGain();
    final highPass = context.createBiquadFilter()
      ..type = 'highpass'
      ..frequency.value = settings.highPass.frequencyHz
      ..Q.value = settings.highPass.q;
    final lowPass = context.createBiquadFilter()
      ..type = 'lowpass'
      ..frequency.value = settings.lowPass.frequencyHz
      ..Q.value = settings.lowPass.q;
    final highPassDry = context.createGain()
      ..gain.value = settings.highPass.enabled ? 0 : 1;
    final highPassWet = context.createGain()
      ..gain.value = settings.highPass.enabled ? 1 : 0;
    final highPassSum = context.createGain();
    final lowPassDry = context.createGain()
      ..gain.value = settings.lowPass.enabled ? 0 : 1;
    final lowPassWet = context.createGain()
      ..gain.value = settings.lowPass.enabled ? 1 : 0;
    final lowPassSum = context.createGain();
    final globalDry = context.createGain()
      ..gain.value = settings.enabled ? 0 : 1;
    final globalWet = context.createGain()
      ..gain.value = settings.enabled ? 1 : 0;

    input.connect(globalDry);
    globalDry.connect(output);
    input.connect(highPassDry);
    input.connect(highPass);
    highPassDry.connect(highPassSum);
    highPass.connect(highPassWet);
    highPassWet.connect(highPassSum);
    highPassSum.connect(lowPassDry);
    highPassSum.connect(lowPass);
    lowPassDry.connect(lowPassSum);
    lowPass.connect(lowPassWet);
    lowPassWet.connect(lowPassSum);
    lowPassSum.connect(globalWet);
    globalWet.connect(output);

    return _TrackFilterRuntime(
      input: input,
      output: output,
      highPass: highPass,
      lowPass: lowPass,
      highPassDry: highPassDry,
      highPassWet: highPassWet,
      lowPassDry: lowPassDry,
      lowPassWet: lowPassWet,
      globalDry: globalDry,
      globalWet: globalWet,
      nodes: [
        input,
        output,
        highPass,
        lowPass,
        highPassDry,
        highPassWet,
        highPassSum,
        lowPassDry,
        lowPassWet,
        lowPassSum,
        globalDry,
        globalWet,
      ],
    );
  }

  @override
  final web.GainNode input;
  @override
  final web.GainNode output;
  final web.BiquadFilterNode highPass;
  final web.BiquadFilterNode lowPass;
  final web.GainNode highPassDry;
  final web.GainNode highPassWet;
  final web.GainNode lowPassDry;
  final web.GainNode lowPassWet;
  final web.GainNode globalDry;
  final web.GainNode globalWet;
  final List<web.AudioNode> nodes;

  void update(TrackFilterFx settings, WebAudioEngine engine) {
    engine._smoothAudioParamTo(
      highPass.frequency,
      settings.highPass.frequencyHz,
    );
    engine._smoothAudioParamTo(highPass.Q, settings.highPass.q);
    engine._smoothAudioParamTo(lowPass.frequency, settings.lowPass.frequencyHz);
    engine._smoothAudioParamTo(lowPass.Q, settings.lowPass.q);
    _setBypassPair(
      dry: highPassDry,
      wet: highPassWet,
      enabled: settings.highPass.enabled,
      engine: engine,
    );
    _setBypassPair(
      dry: lowPassDry,
      wet: lowPassWet,
      enabled: settings.lowPass.enabled,
      engine: engine,
    );
    _setBypassPair(
      dry: globalDry,
      wet: globalWet,
      enabled: settings.enabled,
      engine: engine,
    );
  }

  static void _setBypassPair({
    required web.GainNode dry,
    required web.GainNode wet,
    required bool enabled,
    required WebAudioEngine engine,
  }) {
    engine._smoothGainTo(dry, enabled ? 0 : 1);
    engine._smoothGainTo(wet, enabled ? 1 : 0);
  }

  void dispose() {
    for (final node in nodes) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _TrackEqRuntime implements _TrackFxRuntimeModule {
  _TrackEqRuntime({
    required this.input,
    required this.output,
    required this.low,
    required this.mid,
    required this.high,
    required this.nodes,
  });

  factory _TrackEqRuntime.create(
    web.BaseAudioContext context,
    TrackEqFx settings,
  ) {
    final input = context.createGain();
    final low = context.createBiquadFilter()
      ..type = 'lowshelf'
      ..frequency.value = defaultEqLowFrequencyHz
      ..gain.value = settings.enabled ? settings.lowGainDb : 0;
    final mid = context.createBiquadFilter()
      ..type = 'peaking'
      ..frequency.value = settings.midFrequencyHz
      ..Q.value = settings.midQ
      ..gain.value = settings.enabled ? settings.midGainDb : 0;
    final high = context.createBiquadFilter()
      ..type = 'highshelf'
      ..frequency.value = defaultEqHighFrequencyHz
      ..gain.value = settings.enabled ? settings.highGainDb : 0;
    final output = context.createGain();
    input.connect(low);
    low.connect(mid);
    mid.connect(high);
    high.connect(output);
    return _TrackEqRuntime(
      input: input,
      output: output,
      low: low,
      mid: mid,
      high: high,
      nodes: [input, low, mid, high, output],
    );
  }

  @override
  final web.GainNode input;
  @override
  final web.GainNode output;
  final web.BiquadFilterNode low;
  final web.BiquadFilterNode mid;
  final web.BiquadFilterNode high;
  final List<web.AudioNode> nodes;

  void update(TrackEqFx settings, WebAudioEngine engine) {
    engine._smoothAudioParamTo(
      low.gain,
      settings.enabled ? settings.lowGainDb : 0,
    );
    engine._smoothAudioParamTo(mid.frequency, settings.midFrequencyHz);
    engine._smoothAudioParamTo(mid.Q, settings.midQ);
    engine._smoothAudioParamTo(
      mid.gain,
      settings.enabled ? settings.midGainDb : 0,
    );
    engine._smoothAudioParamTo(
      high.gain,
      settings.enabled ? settings.highGainDb : 0,
    );
  }

  void dispose() {
    for (final node in nodes) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _TrackCompressorRuntime implements _TrackFxRuntimeModule {
  _TrackCompressorRuntime({
    required this.input,
    required this.output,
    required this.compressor,
    required this.makeupGain,
    required this.dryGain,
    required this.wetGain,
    required this.nodes,
    required this.enabled,
  });

  factory _TrackCompressorRuntime.create(
    web.BaseAudioContext context,
    TrackCompressorFx settings,
  ) {
    final input = context.createGain();
    final output = context.createGain();
    final compressor = context.createDynamicsCompressor()
      ..threshold.value = settings.thresholdDb
      ..ratio.value = settings.ratio
      ..attack.value = settings.attackSeconds
      ..release.value = settings.releaseSeconds;
    final makeupGain = context.createGain()
      ..gain.value = compressorMakeupDbToLinear(settings.makeupGainDb);
    final dryGain = context.createGain()..gain.value = settings.enabled ? 0 : 1;
    final wetGain = context.createGain()..gain.value = settings.enabled ? 1 : 0;

    input.connect(dryGain);
    dryGain.connect(output);
    input.connect(compressor);
    compressor.connect(makeupGain);
    makeupGain.connect(wetGain);
    wetGain.connect(output);

    return _TrackCompressorRuntime(
      input: input,
      output: output,
      compressor: compressor,
      makeupGain: makeupGain,
      dryGain: dryGain,
      wetGain: wetGain,
      nodes: [input, output, compressor, makeupGain, dryGain, wetGain],
      enabled: settings.enabled,
    );
  }

  @override
  final web.GainNode input;
  @override
  final web.GainNode output;
  final web.DynamicsCompressorNode compressor;
  final web.GainNode makeupGain;
  final web.GainNode dryGain;
  final web.GainNode wetGain;
  final List<web.AudioNode> nodes;
  bool enabled;

  double get reductionDb {
    if (!enabled) return 0;
    final reduction = compressor.reduction;
    if (!reduction.isFinite) return 0;
    return reduction.clamp(-24.0, 0.0);
  }

  void update(TrackCompressorFx settings, WebAudioEngine engine) {
    enabled = settings.enabled;
    engine._smoothAudioParamTo(compressor.threshold, settings.thresholdDb);
    engine._smoothAudioParamTo(compressor.ratio, settings.ratio);
    engine._smoothAudioParamTo(compressor.attack, settings.attackSeconds);
    engine._smoothAudioParamTo(compressor.release, settings.releaseSeconds);
    engine._smoothGainTo(
      makeupGain,
      compressorMakeupDbToLinear(settings.makeupGainDb),
    );
    _TrackFilterRuntime._setBypassPair(
      dry: dryGain,
      wet: wetGain,
      enabled: settings.enabled,
      engine: engine,
    );
  }

  void dispose() {
    for (final node in nodes) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _TrackDelayRuntime implements _TrackFxRuntimeModule {
  _TrackDelayRuntime._({
    required this.context,
    required this.input,
    required this.output,
    required this.dryGain,
    required this.wetInput,
    required this.settings,
    required this.bpm,
  });

  factory _TrackDelayRuntime.create(
    web.BaseAudioContext context,
    TrackDelayFx settings,
    double bpm,
  ) {
    final input = context.createGain();
    final output = context.createGain();
    final dryGain = context.createGain();
    final wetInput = context.createGain();
    input.connect(dryGain);
    dryGain.connect(output);
    input.connect(wetInput);
    final runtime = _TrackDelayRuntime._(
      context: context,
      input: input,
      output: output,
      dryGain: dryGain,
      wetInput: wetInput,
      settings: settings,
      bpm: bpm,
    );
    runtime._createWetBranch();
    runtime._setImmediateValues();
    return runtime;
  }

  final web.BaseAudioContext context;
  @override
  final web.GainNode input;
  @override
  final web.GainNode output;
  final web.GainNode dryGain;
  final web.GainNode wetInput;
  late web.DelayNode delayNode;
  late web.GainNode feedbackGain;
  late web.GainNode wetGain;
  TrackDelayFx settings;
  double bpm;

  void _createWetBranch() {
    delayNode = context.createDelay(5);
    feedbackGain = context.createGain();
    wetGain = context.createGain();
    wetInput.connect(delayNode);
    delayNode.connect(wetGain);
    wetGain.connect(output);
    delayNode.connect(feedbackGain);
    feedbackGain.connect(delayNode);
  }

  void _setImmediateValues() {
    final enabled = settings.enabled;
    delayNode.delayTime.value = effectiveDelayTimeSeconds(settings, bpm);
    dryGain.gain.value = enabled ? delayDryGain(settings.mix) : 1;
    wetInput.gain.value = enabled ? 1 : 0;
    wetGain.gain.value = enabled ? delayWetGain(settings.mix) : 0;
    feedbackGain.gain.value = enabled
        ? clampDelayFeedback(settings.feedback)
        : 0;
  }

  void update(TrackDelayFx next, double nextBpm, WebAudioEngine engine) {
    final enabledChanged = next.enabled != settings.enabled;
    settings = next;
    bpm = nextBpm;
    if (enabledChanged) {
      resetTail();
      return;
    }
    final enabled = settings.enabled;
    engine._smoothAudioParamTo(
      delayNode.delayTime,
      effectiveDelayTimeSeconds(settings, bpm),
    );
    engine._smoothGainTo(dryGain, enabled ? delayDryGain(settings.mix) : 1);
    engine._smoothGainTo(wetInput, enabled ? 1 : 0);
    engine._smoothGainTo(wetGain, enabled ? delayWetGain(settings.mix) : 0);
    engine._smoothGainTo(
      feedbackGain,
      enabled ? clampDelayFeedback(settings.feedback) : 0,
    );
  }

  void resetTail() {
    try {
      wetInput.disconnect();
    } catch (_) {}
    for (final node in [delayNode, feedbackGain, wetGain]) {
      try {
        node.disconnect();
      } catch (_) {}
    }
    _createWetBranch();
    _setImmediateValues();
  }

  void dispose() {
    for (final node in [
      input,
      output,
      dryGain,
      wetInput,
      delayNode,
      feedbackGain,
      wetGain,
    ]) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _TrackReverbRuntime implements _TrackFxRuntimeModule {
  _TrackReverbRuntime._({
    required this.context,
    required this.engine,
    required this.input,
    required this.output,
    required this.dryGain,
    required this.wetInput,
    required this.settings,
  });

  factory _TrackReverbRuntime.create(
    web.BaseAudioContext context,
    TrackReverbFx settings,
    WebAudioEngine engine,
  ) {
    final input = context.createGain();
    final output = context.createGain();
    final dryGain = context.createGain();
    final wetInput = context.createGain();
    input.connect(dryGain);
    dryGain.connect(output);
    input.connect(wetInput);
    final runtime = _TrackReverbRuntime._(
      context: context,
      engine: engine,
      input: input,
      output: output,
      dryGain: dryGain,
      wetInput: wetInput,
      settings: settings,
    );
    runtime._createWetBranch();
    runtime._setImmediateValues();
    return runtime;
  }

  final web.BaseAudioContext context;
  final WebAudioEngine engine;
  @override
  final web.GainNode input;
  @override
  final web.GainNode output;
  final web.GainNode dryGain;
  final web.GainNode wetInput;
  late web.DelayNode preDelay;
  late web.ConvolverNode convolver;
  late web.BiquadFilterNode damping;
  late web.GainNode wetGain;
  TrackReverbFx settings;

  void _createWetBranch() {
    preDelay = context.createDelay(maximumReverbPreDelaySeconds);
    convolver = context.createConvolver()
      ..normalize = false
      ..buffer = engine._reverbImpulseBuffer(settings.decaySeconds);
    damping = context.createBiquadFilter()
      ..type = 'lowpass'
      ..Q.value = 0.707;
    wetGain = context.createGain();
    wetInput.connect(preDelay);
    preDelay.connect(convolver);
    convolver.connect(damping);
    damping.connect(wetGain);
    wetGain.connect(output);
  }

  void _setImmediateValues() {
    final enabled = settings.enabled;
    preDelay.delayTime.value = clampReverbPreDelaySeconds(
      settings.preDelaySeconds,
    );
    damping.frequency.value = clampReverbDampingHz(settings.dampingHz);
    dryGain.gain.value = enabled ? reverbDryGain(settings.mix) : 1;
    wetInput.gain.value = enabled ? 1 : 0;
    wetGain.gain.value = enabled ? reverbWetGain(settings.mix) : 0;
  }

  void update(TrackReverbFx next, WebAudioEngine engine) {
    final mustResetTail =
        next.enabled != settings.enabled ||
        next.decaySeconds != settings.decaySeconds;
    settings = next;
    if (mustResetTail) {
      resetTail();
      return;
    }
    final enabled = settings.enabled;
    engine._smoothAudioParamTo(
      preDelay.delayTime,
      clampReverbPreDelaySeconds(settings.preDelaySeconds),
    );
    engine._smoothAudioParamTo(
      damping.frequency,
      clampReverbDampingHz(settings.dampingHz),
    );
    engine._smoothGainTo(dryGain, enabled ? reverbDryGain(settings.mix) : 1);
    engine._smoothGainTo(wetInput, enabled ? 1 : 0);
    engine._smoothGainTo(wetGain, enabled ? reverbWetGain(settings.mix) : 0);
  }

  void resetTail() {
    try {
      wetInput.disconnect();
    } catch (_) {}
    for (final node in [preDelay, convolver, damping, wetGain]) {
      try {
        node.disconnect();
      } catch (_) {}
    }
    _createWetBranch();
    _setImmediateValues();
  }

  void dispose() {
    for (final node in [
      input,
      output,
      dryGain,
      wetInput,
      preDelay,
      convolver,
      damping,
      wetGain,
    ]) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _MasterLimiterRuntime {
  _MasterLimiterRuntime({
    required this.input,
    required this.output,
    required this.compressor,
    required this.ceiling,
    required this.dryGain,
    required this.wetGain,
    required this.settings,
  });

  factory _MasterLimiterRuntime.create(
    web.BaseAudioContext context,
    MasterLimiterSettings settings,
  ) {
    final clamped = settings.clamped();
    final input = context.createGain();
    final output = context.createGain();
    final compressor = context.createDynamicsCompressor()
      ..threshold.value = clamped.thresholdDb
      ..knee.value = masterLimiterKneeDb
      ..ratio.value = masterLimiterRatio
      ..attack.value = masterLimiterAttackSeconds
      ..release.value = clamped.releaseSeconds;
    final ceiling = context.createWaveShaper()
      ..curve = createMasterLimiterCeilingCurve(clamped.ceilingDb).toJS
      ..oversample = 'none';
    final dryGain = context.createGain()..gain.value = clamped.enabled ? 0 : 1;
    final wetGain = context.createGain()..gain.value = clamped.enabled ? 1 : 0;

    input.connect(dryGain);
    dryGain.connect(output);
    input.connect(compressor);
    compressor.connect(ceiling);
    ceiling.connect(wetGain);
    wetGain.connect(output);

    return _MasterLimiterRuntime(
      input: input,
      output: output,
      compressor: compressor,
      ceiling: ceiling,
      dryGain: dryGain,
      wetGain: wetGain,
      settings: clamped,
    );
  }

  final web.GainNode input;
  final web.GainNode output;
  final web.DynamicsCompressorNode compressor;
  final web.WaveShaperNode ceiling;
  final web.GainNode dryGain;
  final web.GainNode wetGain;
  MasterLimiterSettings settings;

  double get reductionDb {
    if (!settings.enabled) return 0;
    final reduction = compressor.reduction;
    if (!reduction.isFinite) return 0;
    return reduction.clamp(-24.0, 0.0);
  }

  void update(MasterLimiterSettings next, WebAudioEngine engine) {
    final clamped = next.clamped();
    engine._smoothAudioParamTo(compressor.threshold, clamped.thresholdDb);
    engine._smoothAudioParamTo(compressor.release, clamped.releaseSeconds);
    if (clamped.ceilingDb != settings.ceilingDb) {
      ceiling.curve = createMasterLimiterCeilingCurve(clamped.ceilingDb).toJS;
    }
    if (clamped.enabled != settings.enabled) {
      final now = engine._audioContext.currentTime;
      dryGain.gain.setValueAtTime(clamped.enabled ? 0 : 1, now);
      wetGain.gain.setValueAtTime(clamped.enabled ? 1 : 0, now);
    }
    settings = clamped;
  }

  void dispose() {
    for (final node in [input, output, compressor, ceiling, dryGain, wetGain]) {
      try {
        node.disconnect();
      } catch (_) {}
    }
  }
}

class _StereoMeterTap {
  _StereoMeterTap._({
    required this.splitter,
    required this.leftAnalyser,
    required this.rightAnalyser,
  });

  static const int _sampleCount = 256;

  final web.ChannelSplitterNode splitter;
  final web.AnalyserNode leftAnalyser;
  final web.AnalyserNode rightAnalyser;
  final JSFloat32Array _leftSamples = Float32List(_sampleCount).toJS;
  final JSFloat32Array _rightSamples = Float32List(_sampleCount).toJS;

  factory _StereoMeterTap.create(
    web.AudioContext context,
    web.AudioNode source,
  ) {
    final splitter = context.createChannelSplitter(2);
    final leftAnalyser = context.createAnalyser();
    final rightAnalyser = context.createAnalyser();
    leftAnalyser
      ..fftSize = _sampleCount
      ..smoothingTimeConstant = 0;
    rightAnalyser
      ..fftSize = _sampleCount
      ..smoothingTimeConstant = 0;
    source.connect(splitter);
    splitter.connect(leftAnalyser, 0);
    splitter.connect(rightAnalyser, 1);
    return _StereoMeterTap._(
      splitter: splitter,
      leftAnalyser: leftAnalyser,
      rightAnalyser: rightAnalyser,
    );
  }

  StereoPeak readPeak() {
    leftAnalyser.getFloatTimeDomainData(_leftSamples);
    rightAnalyser.getFloatTimeDomainData(_rightSamples);
    return StereoPeak(
      left: _peakAmplitude(_leftSamples.toDart),
      right: _peakAmplitude(_rightSamples.toDart),
    );
  }

  static double _peakAmplitude(Float32List samples) {
    var peak = 0.0;
    for (final sample in samples) {
      peak = math.max(peak, sample.abs());
    }
    return peak;
  }

  void dispose() {
    try {
      splitter.disconnect();
    } catch (_) {}
    try {
      leftAnalyser.disconnect();
    } catch (_) {}
    try {
      rightAnalyser.disconnect();
    } catch (_) {}
  }
}

class _ScheduledSource {
  const _ScheduledSource({
    required this.node,
    required this.clipId,
    required this.fadeGain,
    required this.clipGain,
    required this.endTime,
  });

  final web.AudioBufferSourceNode node;
  final String clipId;
  final web.GainNode fadeGain;
  final web.GainNode clipGain;
  final double endTime;
}

final webAudioEngineProvider = Provider<WebAudioEngine>((ref) {
  final engine = WebAudioEngine();

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});
