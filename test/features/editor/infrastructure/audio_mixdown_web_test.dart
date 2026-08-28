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
    double gainDb = 0,
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
          gainDb: gainDb,
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

  test('offline WAV applies the live master volume state', () async {
    final unity = _leftChannelRms(
      (await mixdown.generateWavExport([track('unity')])).wavBytes,
    );
    engine.setMasterVolumeDb(-6);
    final quieter = _leftChannelRms(
      (await mixdown.generateWavExport([track('quieter')])).wavBytes,
    );

    expect(quieter / unity, closeTo(0.501187, 0.015));
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

  test('offline WAV applies clip gain independently of fades', () async {
    final unity = _leftChannelRms(
      (await mixdown.generateWavExport([track('unity')])).wavBytes,
    );
    final gainedAndFaded = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'gained',
          gainDb: -6,
          fadeIn: asset.durationSeconds / 2,
          fadeOut: asset.durationSeconds / 2,
        ),
      ])).wavBytes,
    );

    expect(
      gainedAndFaded / unity,
      closeTo(clipGainDbToLinear(-6) * math.sqrt(1 / 3), 0.025),
    );
  });

  test('offline WAV reverses only the trimmed visible source range', () async {
    final frameCount = sampleRate * durationSeconds ~/ 1;
    final ramp = Float32List(frameCount);
    for (var index = 0; index < frameCount; index++) {
      ramp[index] = -0.8 + (1.6 * index / (frameCount - 1));
    }
    final bytes = WavEncoder.encodePcm16(
      channels: [ramp, ramp],
      sampleRate: sampleRate,
    );
    final decoded = await engine.decode(assetId: 'asset-ramp', bytes: bytes);
    final rampAsset = AudioAsset(
      id: 'asset-ramp',
      name: 'ramp.wav',
      extension: 'wav',
      size: bytes.length,
      durationSeconds: decoded.durationSeconds,
      sampleRate: decoded.sampleRate,
      numberOfChannels: decoded.numberOfChannels,
      waveformPeaks: decoded.waveformPeaks,
    );
    const sourceStart = 0.02;
    const clipDuration = 0.06;
    DawTrack arrangement(bool reversed) => DawTrack(
      id: reversed ? 'reversed' : 'normal',
      name: 'Ramp',
      clips: [
        AudioClip(
          id: reversed ? 'clip-reversed' : 'clip-normal',
          audio: rampAsset,
          sourceStartSeconds: sourceStart,
          clipDurationSeconds: clipDuration,
          isReversed: reversed,
        ),
      ],
    );

    final reversedClip = arrangement(true).clips.single;
    final firstBuffer = engine.playbackBufferForClip(reversedClip);
    expect(engine.playbackBufferForClip(reversedClip), same(firstBuffer));

    final normalSamples = _leftChannelSamples(
      (await mixdown.generateWavExport([arrangement(false)])).wavBytes,
    );
    final reversedSamples = _leftChannelSamples(
      (await mixdown.generateWavExport([arrangement(true)])).wavBytes,
    );

    expect(reversedSamples, hasLength(normalSamples.length));
    for (final index in [100, 700, 1400, 2200]) {
      expect(
        reversedSamples[index],
        closeTo(normalSamples[normalSamples.length - index - 1], 0.003),
      );
    }
  });
}

double _leftChannelRms(Uint8List wavBytes) {
  return _stereoChannelRms(wavBytes).left;
}

List<double> _leftChannelSamples(Uint8List wavBytes) {
  final data = ByteData.sublistView(wavBytes);
  const headerLength = 44;
  const stereoFrameBytes = 4;
  final frameCount = (wavBytes.length - headerLength) ~/ stereoFrameBytes;
  return [
    for (var frame = 0; frame < frameCount; frame++)
      data.getInt16(headerLength + frame * stereoFrameBytes, Endian.little) /
          32768,
  ];
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
