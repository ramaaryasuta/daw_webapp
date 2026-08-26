import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/daw_track.dart';
import '../domain/loop_region.dart';
import '../domain/track_mixer.dart';
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

class WebAudioEngine {
  WebAudioEngine() : _audioContext = web.AudioContext() {
    _metronomeScheduler = WebMetronomeScheduler(_audioContext);
  }

  final web.AudioContext _audioContext;
  late final WebMetronomeScheduler _metronomeScheduler;

  final Map<String, web.AudioBuffer> _buffers = {};

  final Map<String, List<_ScheduledSource>> _activeSources = {};

  final Map<String, web.GainNode> _trackGains = {};
  final Map<String, web.StereoPannerNode> _trackPanners = {};

  bool _isPlaying = false;
  int _playRequestId = 0;

  double _timelineStartSeconds = 0;
  double _contextStartTime = 0;

  double _projectDurationSeconds = 0;

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

  web.AudioBuffer? decodedBufferForAsset(String assetId) {
    return _buffers[assetId];
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
    final byteBuffer = Uint8List.fromList(bytes).buffer;

    final audioBuffer = await _audioContext
        .decodeAudioData(byteBuffer.toJS)
        .toDart;

    _buffers[assetId] = audioBuffer;

    final waveformPeaks = _extractWaveformPeaks(audioBuffer);

    return DecodedAudioInfo(
      durationSeconds: audioBuffer.duration,
      sampleRate: audioBuffer.sampleRate,
      numberOfChannels: audioBuffer.numberOfChannels,
      waveformPeaks: waveformPeaks,
    );
  }

  Future<void> play({
    required List<DawTrack> tracks,
    required double fromSeconds,
    LoopRegion? loopRegion,
  }) async {
    final projectDuration = calculateProjectDurationSeconds(tracks);
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

    _createTrackMixerNodes(tracks);

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

  void _createTrackMixerNodes(List<DawTrack> tracks) {
    final hasSolo = tracks.any((track) => track.isSolo);

    for (final track in tracks) {
      final gain = _audioContext.createGain();
      final panner = _audioContext.createStereoPanner();
      gain.gain.value = effectiveTrackGain(track, hasSolo: hasSolo);
      panner.pan.value = clampTrackPan(track.pan);
      gain.connect(panner);
      panner.connect(_audioContext.destination);
      _trackGains[track.id] = gain;
      _trackPanners[track.id] = panner;
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
      final gain = _trackGains[track.id];
      if (gain == null) {
        continue;
      }
      for (final clip in track.clips) {
        final buffer = _buffers[clip.audio.id];
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
        source.buffer = buffer;
        source.connect(gain);
        final sourceStartTime = contextStartTime + playbackTiming.delaySeconds;
        final scheduledSource = _ScheduledSource(
          node: source,
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
    _projectDurationSeconds = calculateProjectDurationSeconds(tracks);
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
      }
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

    _activeSources.clear();
    _trackGains.clear();
    _trackPanners.clear();
    _scheduledTracks = const [];
    _contextStartTime = 0;
  }

  void setTempoBpm(double tempoBpm) {
    _metronomeScheduler.setTempoBpm(tempoBpm);
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
    }
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

  void removeTrack(String trackId) {
    final sources = _activeSources.remove(trackId);

    if (sources != null) {
      for (final source in sources) {
        try {
          source.node.stop();
          source.node.disconnect();
        } catch (_) {}
      }
    }

    final gain = _trackGains.remove(trackId);
    final panner = _trackPanners.remove(trackId);

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

  Future<void> dispose() async {
    _playRequestId++;
    stopSources();
    _metronomeScheduler.dispose();
    _buffers.clear();

    await _audioContext.close().toDart;
  }
}

class _ScheduledSource {
  const _ScheduledSource({required this.node, required this.endTime});

  final web.AudioBufferSourceNode node;
  final double endTime;
}

final webAudioEngineProvider = Provider<WebAudioEngine>((ref) {
  final engine = WebAudioEngine();

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});
