import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/daw_track.dart';
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

  final Map<String, web.AudioBufferSourceNode> _activeSources = {};

  final Map<String, web.GainNode> _trackGains = {};

  bool _isPlaying = false;
  int _playRequestId = 0;

  double _timelineStartSeconds = 0;
  double _contextStartTime = 0;

  double _projectDurationSeconds = 0;

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

    return (_timelineStartSeconds + elapsed).clamp(
      0.0,
      _projectDurationSeconds,
    );
  }

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
  }) async {
    if (tracks.isEmpty) {
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

    _projectDurationSeconds = calculateProjectDurationSeconds(tracks);

    if (fromSeconds >= _projectDurationSeconds) {
      fromSeconds = 0;
    }

    _timelineStartSeconds = fromSeconds;

    // Berikan sedikit lead time.
    //
    // Semua node kemudian dijadwalkan terhadap
    // clock yang sama.
    final startAt = _audioContext.currentTime + 0.03;

    _contextStartTime = startAt;

    final hasSolo = tracks.any((track) => track.isSolo);

    for (final track in tracks) {
      final buffer = _buffers[track.clip.audio.id];

      if (buffer == null) {
        continue;
      }

      final playbackTiming = track.clip.playbackTimingFrom(fromSeconds);

      // Clip sudah habis sebelum posisi playhead.
      if (playbackTiming == null ||
          playbackTiming.bufferOffsetSeconds >= buffer.duration) {
        continue;
      }

      final source = _audioContext.createBufferSource();

      source.buffer = buffer;

      final gain = _audioContext.createGain();

      gain.gain.value = effectiveTrackGain(track, hasSolo: hasSolo);

      source.connect(gain);
      gain.connect(_audioContext.destination);

      _activeSources[track.id] = source;
      _trackGains[track.id] = gain;

      source.start(
        startAt + playbackTiming.delaySeconds,
        playbackTiming.bufferOffsetSeconds,
        playbackTiming.playbackDurationSeconds,
      );
    }

    _metronomeScheduler.startTransport(
      timelineStartSeconds: _timelineStartSeconds,
      contextStartTime: _contextStartTime,
    );
    _isPlaying = true;
  }

  Future<void> seek({
    required List<DawTrack> tracks,
    required double positionSeconds,
  }) async {
    _projectDurationSeconds = calculateProjectDurationSeconds(tracks);

    final position = positionSeconds.clamp(0.0, _projectDurationSeconds);
    final shouldResumePlayback =
        _isPlaying && position < _projectDurationSeconds;

    _playRequestId++;
    stopSources();
    _timelineStartSeconds = position;
    _isPlaying = false;

    if (shouldResumePlayback) {
      await play(tracks: tracks, fromSeconds: position);
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
    _metronomeScheduler.stopTransport();

    for (final source in _activeSources.values) {
      try {
        source.stop();
      } catch (_) {
        // Source mungkin sudah selesai.
      }

      try {
        source.disconnect();
      } catch (_) {}
    }

    for (final gain in _trackGains.values) {
      try {
        gain.disconnect();
      } catch (_) {}
    }

    _activeSources.clear();
    _trackGains.clear();
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

      if (gain == null) {
        continue;
      }

      gain.gain.value = effectiveTrackGain(track, hasSolo: hasSolo);
    }
  }

  void removeTrack(String trackId) {
    final source = _activeSources.remove(trackId);

    if (source != null) {
      try {
        source.stop();
        source.disconnect();
      } catch (_) {}
    }

    final gain = _trackGains.remove(trackId);

    if (gain != null) {
      try {
        gain.disconnect();
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

final webAudioEngineProvider = Provider<WebAudioEngine>((ref) {
  final engine = WebAudioEngine();

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});
