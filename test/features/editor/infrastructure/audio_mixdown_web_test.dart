@TestOn('browser')
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/infrastructure/audio_mixdown_service.dart';
import 'package:daw_webapp/features/editor/infrastructure/wav_encoder.dart';
import 'package:daw_webapp/features/editor/infrastructure/web_audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleRate = 48000;
  const durationSeconds = 0.12;
  late WebAudioEngine engine;
  late AudioMixdownService mixdown;
  late AudioAsset asset;

  setUp(() async {
    engine = WebAudioEngine();
    mixdown = AudioMixdownService(engine);
    final samples = Float32List(sampleRate * durationSeconds ~/ 1)
      ..fillRange(0, sampleRate * durationSeconds ~/ 1, 0.1);
    final bytes = WavEncoder.encodePcm16(
      channels: [samples, samples],
      sampleRate: sampleRate,
    );
    final decoded = await engine.decode(assetId: 'asset-1', bytes: bytes);
    asset = AudioAsset(
      id: 'asset-1',
      name: 'tone.wav',
      extension: 'wav',
      size: bytes.length,
      durationSeconds: decoded.durationSeconds,
      sampleRate: decoded.sampleRate,
      numberOfChannels: decoded.numberOfChannels,
      waveformPeaks: decoded.waveformPeaks,
    );
  });

  tearDown(() async {
    await engine.dispose();
  });

  DawTrack track(
    String id, {
    double volumeDb = 0,
    double pan = 0,
    bool isMuted = false,
    bool isSolo = false,
    double fadeIn = 0,
    double fadeOut = 0,
  }) {
    return DawTrack(
      id: id,
      name: id,
      volumeDb: volumeDb,
      pan: pan,
      isMuted: isMuted,
      isSolo: isSolo,
      clips: [
        AudioClip(
          id: 'clip-$id',
          audio: asset,
          clipDurationSeconds: asset.durationSeconds,
          fadeInDurationSeconds: fadeIn,
          fadeOutDurationSeconds: fadeOut,
        ),
      ],
    );
  }

  test(
    'offline WAV applies volume, mute, solo, and multiple-solo rules',
    () async {
      final unity = _leftChannelRms(
        (await mixdown.generateWavExport([track('a')])).wavBytes,
      );
      final minusSix = _leftChannelRms(
        (await mixdown.generateWavExport([track('b', volumeDb: -6)])).wavBytes,
      );
      expect(minusSix / unity, closeTo(0.501187, 0.015));

      final muted = _leftChannelRms(
        (await mixdown.generateWavExport([
          track('muted', isMuted: true),
        ])).wavBytes,
      );
      expect(muted, lessThan(0.00001));

      final soloOnly = _leftChannelRms(
        (await mixdown.generateWavExport([
          track('a'),
          track('b', volumeDb: -6, isSolo: true),
          track('c'),
        ])).wavBytes,
      );
      expect(soloOnly / unity, closeTo(0.501187, 0.015));

      final multipleSolo = _leftChannelRms(
        (await mixdown.generateWavExport([
          track('a', isSolo: true),
          track('b', volumeDb: -6, isSolo: true),
          track('c'),
        ])).wavBytes,
      );
      expect(multipleSolo / unity, closeTo(1.501187, 0.025));

      final muteWins = _leftChannelRms(
        (await mixdown.generateWavExport([
          track('a'),
          track('b', isSolo: true, isMuted: true),
        ])).wavBytes,
      );
      expect(muteWins, lessThan(0.00001));
    },
  );

  test('offline WAV applies stereo track pan', () async {
    final centered = await mixdown.generateWavExport([track('center')]);
    final hardLeft = await mixdown.generateWavExport([track('left', pan: -1)]);
    final hardRight = await mixdown.generateWavExport([track('right', pan: 1)]);

    final centeredRms = _stereoChannelRms(centered.wavBytes);
    final leftRms = _stereoChannelRms(hardLeft.wavBytes);
    final rightRms = _stereoChannelRms(hardRight.wavBytes);

    expect(centeredRms.left, closeTo(centeredRms.right, 0.0001));
    expect(leftRms.left, greaterThan(0.05));
    expect(leftRms.right, lessThan(0.0001));
    expect(rightRms.left, lessThan(0.0001));
    expect(rightRms.right, greaterThan(0.05));
  });

  test('offline WAV applies clip fade envelopes', () async {
    final unity = _leftChannelRms(
      (await mixdown.generateWavExport([track('unity')])).wavBytes,
    );
    final fullyFaded = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'faded',
          fadeIn: asset.durationSeconds / 2,
          fadeOut: asset.durationSeconds / 2,
        ),
      ])).wavBytes,
    );

    expect(fullyFaded / unity, closeTo(math.sqrt(1 / 3), 0.035));
  });
}

double _leftChannelRms(Uint8List wavBytes) {
  return _stereoChannelRms(wavBytes).left;
}

({double left, double right}) _stereoChannelRms(Uint8List wavBytes) {
  final data = ByteData.sublistView(wavBytes);
  const headerLength = 44;
  const stereoFrameBytes = 4;
  final frameCount = (wavBytes.length - headerLength) ~/ stereoFrameBytes;
  var leftSquareSum = 0.0;
  var rightSquareSum = 0.0;
  for (var frame = 0; frame < frameCount; frame++) {
    final leftSample =
        data.getInt16(headerLength + frame * stereoFrameBytes, Endian.little) /
        32768;
    final rightSample =
        data.getInt16(
          headerLength + frame * stereoFrameBytes + 2,
          Endian.little,
        ) /
        32768;
    leftSquareSum += leftSample * leftSample;
    rightSquareSum += rightSample * rightSample;
  }
  return (
    left: math.sqrt(leftSquareSum / frameCount),
    right: math.sqrt(rightSquareSum / frameCount),
  );
}
