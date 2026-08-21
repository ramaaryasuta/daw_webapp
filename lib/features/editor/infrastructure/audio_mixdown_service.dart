import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/daw_track.dart';
import 'wav_encoder.dart';
import 'web_audio_engine.dart';

class RenderedAudioMix {
  const RenderedAudioMix({
    required this.wavBytes,
    required this.durationSeconds,
    required this.sampleRate,
    required this.channelCount,
  });

  final Uint8List wavBytes;
  final double durationSeconds;
  final int sampleRate;
  final int channelCount;
}

class AudioMixdownException implements Exception {
  const AudioMixdownException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AudioMixdownService {
  const AudioMixdownService(this._audioEngine);

  static const int _channelCount = 2;
  static const double _maximumDurationSeconds = 4 * 60 * 60;

  final WebAudioEngine _audioEngine;

  Future<RenderedAudioMix> renderStereoWav(List<DawTrack> tracks) async {
    if (tracks.isEmpty) {
      throw const AudioMixdownException('The project has no audio to export.');
    }

    final durationSeconds = calculateProjectDurationSeconds(tracks);
    if (!durationSeconds.isFinite ||
        durationSeconds <= 0 ||
        durationSeconds > _maximumDurationSeconds) {
      throw const AudioMixdownException(
        'The project duration cannot be rendered safely.',
      );
    }

    final sampleRate = _audioEngine.sampleRate.round();
    final frameCount = math.max(1, (durationSeconds * sampleRate).ceil());
    final wavDataLength =
        frameCount * _channelCount * (WavEncoder.bitsPerSample ~/ 8);
    if (wavDataLength > 0xffffffff - 36) {
      throw const AudioMixdownException(
        'This project is too large to export as a standard WAV file.',
      );
    }
    final offlineContext = web.OfflineAudioContext(
      web.OfflineAudioContextOptions(
        numberOfChannels: _channelCount,
        length: frameCount,
        sampleRate: sampleRate,
      ),
    );
    final hasSolo = tracks.any((track) => track.isSolo);

    for (final track in tracks) {
      final gainValue = effectiveTrackGain(track, hasSolo: hasSolo);
      if (gainValue == 0) {
        continue;
      }

      final buffer = _audioEngine.decodedBufferForAsset(track.clip.audio.id);
      if (buffer == null) {
        throw AudioMixdownException(
          'Audio data for ${track.clip.audio.name} is unavailable.',
        );
      }

      final source = offlineContext.createBufferSource();
      final gain = offlineContext.createGain();
      source.buffer = buffer;
      gain.gain.value = gainValue;
      source.connect(gain);
      gain.connect(offlineContext.destination);
      source.start(track.clip.timelineStartSeconds, 0);
    }

    final renderedBuffer = await offlineContext.startRendering().toDart;
    final channels = <Float32List>[
      for (var channel = 0; channel < _channelCount; channel++)
        renderedBuffer.getChannelData(channel).toDart,
    ];
    final wavBytes = WavEncoder.encodePcm16(
      channels: channels,
      sampleRate: sampleRate,
    );

    return RenderedAudioMix(
      wavBytes: wavBytes,
      durationSeconds: renderedBuffer.duration,
      sampleRate: sampleRate,
      channelCount: _channelCount,
    );
  }
}

final audioMixdownServiceProvider = Provider<AudioMixdownService>((ref) {
  return AudioMixdownService(ref.read(webAudioEngineProvider));
});
