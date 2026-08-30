import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../domain/audio_clip.dart';
import '../domain/daw_track.dart';
import '../domain/track_mixer.dart';
import '../domain/track_eq_fx.dart';
import '../domain/track_compressor_fx.dart';
import '../domain/track_fx_chain.dart';
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
    final masterGain = offlineContext.createGain();
    masterGain.gain.value = masterDbToLinearGain(_audioEngine.masterVolumeDb);
    masterGain.connect(offlineContext.destination);

    for (final track in tracks) {
      final gainValue = effectiveTrackGain(track, hasSolo: hasSolo);
      if (gainValue == 0) {
        continue;
      }

      final gain = offlineContext.createGain();
      final panner = offlineContext.createStereoPanner();
      final fxInput = offlineContext.createGain();
      web.AudioNode fxTail = fxInput;
      for (final effect in track.fxChainOrder) {
        switch (effect) {
          case TrackFxType.filter:
            if (track.filterFx.enabled && track.filterFx.highPass.enabled) {
              final highPass = offlineContext.createBiquadFilter()
                ..type = 'highpass'
                ..frequency.value = track.filterFx.highPass.frequencyHz
                ..Q.value = track.filterFx.highPass.q;
              fxTail.connect(highPass);
              fxTail = highPass;
            }
            if (track.filterFx.enabled && track.filterFx.lowPass.enabled) {
              final lowPass = offlineContext.createBiquadFilter()
                ..type = 'lowpass'
                ..frequency.value = track.filterFx.lowPass.frequencyHz
                ..Q.value = track.filterFx.lowPass.q;
              fxTail.connect(lowPass);
              fxTail = lowPass;
            }
            break;
          case TrackFxType.eq:
            if (track.eqFx.enabled) {
              final lowEq = offlineContext.createBiquadFilter()
                ..type = 'lowshelf'
                ..frequency.value = defaultEqLowFrequencyHz
                ..gain.value = track.eqFx.lowGainDb;
              final midEq = offlineContext.createBiquadFilter()
                ..type = 'peaking'
                ..frequency.value = track.eqFx.midFrequencyHz
                ..Q.value = track.eqFx.midQ
                ..gain.value = track.eqFx.midGainDb;
              final highEq = offlineContext.createBiquadFilter()
                ..type = 'highshelf'
                ..frequency.value = defaultEqHighFrequencyHz
                ..gain.value = track.eqFx.highGainDb;
              fxTail.connect(lowEq);
              lowEq.connect(midEq);
              midEq.connect(highEq);
              fxTail = highEq;
            }
            break;
          case TrackFxType.compressor:
            if (track.compressorFx.enabled) {
              final compressor = offlineContext.createDynamicsCompressor()
                ..threshold.value = track.compressorFx.thresholdDb
                ..ratio.value = track.compressorFx.ratio
                ..attack.value = track.compressorFx.attackSeconds
                ..release.value = track.compressorFx.releaseSeconds;
              final makeupGain = offlineContext.createGain()
                ..gain.value = compressorMakeupDbToLinear(
                  track.compressorFx.makeupGainDb,
                );
              fxTail.connect(compressor);
              compressor.connect(makeupGain);
              fxTail = makeupGain;
            }
            break;
        }
      }
      gain.gain.value = gainValue;
      panner.pan.value = clampTrackPan(track.pan);
      fxTail.connect(gain);
      gain.connect(panner);
      panner.connect(masterGain);

      for (final clip in track.clips) {
        final buffer = _audioEngine.playbackBufferForClip(clip);
        if (buffer == null) {
          throw AudioMixdownException(
            'Audio data for ${clip.audio.name} is unavailable.',
          );
        }

        final source = offlineContext.createBufferSource();
        final fadeGain = offlineContext.createGain();
        final clipGain = offlineContext.createGain();
        source.buffer = buffer;
        source.connect(fadeGain);
        fadeGain.connect(clipGain);
        clipGain.connect(fxInput);
        clipGain.gain.value = clipGainDbToLinear(clip.gainDb);
        final fadePoints = clipFadeEnvelopeForSegment(
          clip: clip,
          clipLocalStartSeconds: 0,
          playbackDurationSeconds: clip.clipDurationSeconds,
        );
        fadeGain.gain.setValueAtTime(
          fadePoints.first.gain,
          clip.timelineStartSeconds,
        );
        for (final point in fadePoints.skip(1)) {
          fadeGain.gain.linearRampToValueAtTime(
            point.gain,
            clip.timelineStartSeconds + point.offsetSeconds,
          );
        }
        source.start(
          clip.timelineStartSeconds,
          clip.playbackBufferOffsetSeconds(),
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
