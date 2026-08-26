import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/daw_track.dart';
import '../domain/track_mixer.dart';
import 'audio_render_duration.dart';
import 'generated_export.dart';
import 'wav_encoder.dart';
import 'web_audio_engine.dart';

export 'generated_export.dart';

class AudioMixdownException implements Exception {
  const AudioMixdownException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AudioMixdownService implements AudioExportGenerator {
  const AudioMixdownService(this._audioEngine);

  static const int _channelCount = 2;
  static const double _maximumDurationSeconds = 4 * 60 * 60;

  final WebAudioEngine _audioEngine;

  @override
  Future<GeneratedExport> generateWavExport(List<DawTrack> tracks) async {
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

    final audioEngineSampleRate = _audioEngine.sampleRate;
    if (!audioEngineSampleRate.isFinite || audioEngineSampleRate <= 0) {
      throw const AudioMixdownException(
        'The audio sample rate cannot be rendered safely.',
      );
    }

    final sampleRate = audioEngineSampleRate.round();
    final frameCount = calculateOfflineFrameCount(
      durationSeconds: durationSeconds,
      sampleRate: sampleRate.toDouble(),
    );
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

      final gain = offlineContext.createGain();
      final panner = offlineContext.createStereoPanner();
      gain.gain.value = gainValue;
      panner.pan.value = clampTrackPan(track.pan);
      gain.connect(panner);
      panner.connect(offlineContext.destination);

      for (final clip in track.clips) {
        final buffer = _audioEngine.decodedBufferForAsset(clip.audio.id);
        if (buffer == null) {
          throw AudioMixdownException(
            'Audio data for ${clip.audio.name} is unavailable.',
          );
        }

        final source = offlineContext.createBufferSource();
        source.buffer = buffer;
        source.connect(gain);
        source.start(
          clip.timelineStartSeconds,
          clip.sourceStartSeconds,
          clip.clipDurationSeconds,
        );
      }
    }

    final renderedBuffer = await offlineContext.startRendering().toDart;
    final renderedFrameCount = renderedBuffer.length;
    final renderedSampleRate = renderedBuffer.sampleRate;
    final renderedChannelCount = renderedBuffer.numberOfChannels;
    late final double renderedDurationSeconds;
    try {
      renderedDurationSeconds = validateRenderedDurationSeconds(
        durationSeconds: renderedBuffer.duration,
        frameCount: renderedFrameCount,
        sampleRate: renderedSampleRate,
        channelCount: renderedChannelCount,
      );
    } on ArgumentError catch (error) {
      debugPrint(
        '[ExportDebug] rendered buffer is invalid: '
        'duration=${renderedBuffer.duration} '
        'frames=$renderedFrameCount '
        'sampleRate=$renderedSampleRate '
        'channels=$renderedChannelCount; $error',
      );
      throw const AudioMixdownException(
        'The generated audio has invalid duration metadata.',
      );
    }
    final channels = <Float32List>[
      for (var channel = 0; channel < renderedChannelCount; channel++)
        renderedBuffer.getChannelData(channel).toDart,
    ];
    final renderedSampleRateInt = renderedSampleRate.round();
    final wavBytes = await WavEncoder.encodePcm16Async(
      channels: channels,
      sampleRate: renderedSampleRateInt,
    );

    return GeneratedExport(
      wavBytes: wavBytes,
      durationSeconds: renderedDurationSeconds,
      sampleRate: renderedSampleRateInt,
      channelCount: renderedChannelCount,
      fileName: 'daw-export.wav',
    );
  }

  Future<GeneratedExport> renderStereoWav(List<DawTrack> tracks) {
    return generateWavExport(tracks);
  }
}

final audioMixdownServiceProvider = Provider<AudioMixdownService>((ref) {
  return AudioMixdownService(ref.read(webAudioEngineProvider));
});
