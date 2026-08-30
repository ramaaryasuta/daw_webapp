@TestOn('browser')
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_eq_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_compressor_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_fx_chain.dart';
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
    TrackFilterFx filterFx = const TrackFilterFx(),
    TrackEqFx eqFx = const TrackEqFx(),
    TrackCompressorFx compressorFx = const TrackCompressorFx(),
    List<TrackFxType> fxChainOrder = defaultTrackFxChainOrder,
  }) {
    return DawTrack(
      id: id,
      name: id,
      volumeDb: volumeDb,
      pan: pan,
      isMuted: isMuted,
      isSolo: isSolo,
      filterFx: filterFx,
      eqFx: eqFx,
      compressorFx: compressorFx,
      fxChainOrder: fxChainOrder,
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

  test('offline WAV applies HP, LP, and global Filter FX bypass', () async {
    final dryDc = _leftChannelRms(
      (await mixdown.generateWavExport([track('dc-dry')])).wavBytes,
    );
    const highPass = TrackFilterFx(
      enabled: true,
      highPass: TrackFilterModule(enabled: true, frequencyHz: 5000),
    );
    final filteredDc = _leftChannelRms(
      (await mixdown.generateWavExport([
        track('dc-hp', filterFx: highPass),
      ])).wavBytes,
    );
    final bypassedDc = _leftChannelRms(
      (await mixdown.generateWavExport([
        track('dc-bypass', filterFx: highPass.copyWith(enabled: false)),
      ])).wavBytes,
    );
    expect(filteredDc / dryDc, lessThan(0.08));
    expect(bypassedDc / dryDc, closeTo(1, 0.01));

    final frameCount = sampleRate * durationSeconds ~/ 1;
    final highTone = Float32List(frameCount);
    for (var index = 0; index < frameCount; index++) {
      highTone[index] =
          0.2 * math.sin(2 * math.pi * 10000 * index / sampleRate);
    }
    final bytes = WavEncoder.encodePcm16(
      channels: [highTone, highTone],
      sampleRate: sampleRate,
    );
    final decoded = await engine.decode(assetId: 'asset-high', bytes: bytes);
    asset = AudioAsset(
      id: 'asset-high',
      name: 'high.wav',
      extension: 'wav',
      size: bytes.length,
      durationSeconds: decoded.durationSeconds,
      sampleRate: decoded.sampleRate,
      numberOfChannels: decoded.numberOfChannels,
      waveformPeaks: decoded.waveformPeaks,
    );
    final dryHigh = _leftChannelRms(
      (await mixdown.generateWavExport([track('high-dry')])).wavBytes,
    );
    final filteredHigh = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'high-lp',
          filterFx: const TrackFilterFx(
            enabled: true,
            lowPass: TrackFilterModule(enabled: true, frequencyHz: 1000),
          ),
        ),
      ])).wavBytes,
    );
    expect(filteredHigh / dryHigh, lessThan(0.08));
  });

  test(
    'live Filter FX changes keep transport running at its playhead',
    () async {
      final dryTrack = track('live');
      await engine.play(tracks: [dryTrack], fromSeconds: 0);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final before = engine.currentPositionSeconds;

      engine.syncTrackFilterFx([
        dryTrack.copyWith(
          filterFx: const TrackFilterFx(
            enabled: true,
            highPass: TrackFilterModule(
              enabled: true,
              frequencyHz: 240,
              q: 1.25,
            ),
            lowPass: TrackFilterModule(
              enabled: true,
              frequencyHz: 12000,
              q: 0.9,
            ),
          ),
        ),
      ]);
      final after = engine.currentPositionSeconds;

      expect(engine.isPlaying, isTrue);
      expect(after, greaterThanOrEqualTo(before));
      engine.pause();
    },
  );

  test('offline WAV applies 3-Band EQ and its global bypass', () async {
    final frameCount = sampleRate * durationSeconds ~/ 1;
    final tone = Float32List(frameCount);
    for (var index = 0; index < frameCount; index++) {
      tone[index] = 0.1 * math.sin(2 * math.pi * 1000 * index / sampleRate);
    }
    final bytes = WavEncoder.encodePcm16(
      channels: [tone, tone],
      sampleRate: sampleRate,
    );
    final decoded = await engine.decode(assetId: 'asset-eq', bytes: bytes);
    asset = AudioAsset(
      id: 'asset-eq',
      name: 'eq.wav',
      extension: 'wav',
      size: bytes.length,
      durationSeconds: decoded.durationSeconds,
      sampleRate: decoded.sampleRate,
      numberOfChannels: decoded.numberOfChannels,
      waveformPeaks: decoded.waveformPeaks,
    );
    final dry = _leftChannelRms(
      (await mixdown.generateWavExport([track('eq-dry')])).wavBytes,
    );
    const boostedEq = TrackEqFx(
      enabled: true,
      midGainDb: 6,
      midFrequencyHz: 1000,
      midQ: 2,
    );
    final boosted = _leftChannelRms(
      (await mixdown.generateWavExport([
        track('eq-boost', eqFx: boostedEq),
      ])).wavBytes,
    );
    final bypassed = _leftChannelRms(
      (await mixdown.generateWavExport([
        track('eq-bypass', eqFx: boostedEq.copyWith(enabled: false)),
      ])).wavBytes,
    );

    expect(boosted / dry, closeTo(math.pow(10, 6 / 20), 0.08));
    expect(bypassed / dry, closeTo(1, 0.01));
  });

  test('live EQ changes keep transport running at its playhead', () async {
    final dryTrack = track('live-eq');
    await engine.play(tracks: [dryTrack], fromSeconds: 0);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final before = engine.currentPositionSeconds;

    engine.syncTrackEqFx([
      dryTrack.copyWith(
        eqFx: const TrackEqFx(
          enabled: true,
          lowGainDb: 3,
          midGainDb: -2,
          midFrequencyHz: 1800,
          midQ: 2.5,
          highGainDb: 4,
        ),
      ),
    ]);
    final after = engine.currentPositionSeconds;

    expect(engine.isPlaying, isTrue);
    expect(after, greaterThanOrEqualTo(before));
    engine.pause();
  });

  test('offline WAV applies compressor, makeup, and global bypass', () async {
    final dry = _leftChannelRms(
      (await mixdown.generateWavExport([track('comp-dry')])).wavBytes,
    );
    const compressor = TrackCompressorFx(
      enabled: true,
      thresholdDb: -40,
      ratio: 20,
      attackSeconds: 0.001,
      releaseSeconds: 0.02,
    );
    final compressed = _leftChannelRms(
      (await mixdown.generateWavExport([
        track('comp-wet', compressorFx: compressor),
      ])).wavBytes,
    );
    final withMakeup = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'comp-makeup',
          compressorFx: compressor.copyWith(makeupGainDb: 6),
        ),
      ])).wavBytes,
    );
    final bypassed = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'comp-bypass',
          compressorFx: compressor.copyWith(enabled: false, makeupGainDb: 6),
        ),
      ])).wavBytes,
    );

    expect(compressed / dry, lessThan(0.7));
    expect(withMakeup / compressed, closeTo(math.pow(10, 6 / 20), 0.08));
    expect(bypassed / dry, closeTo(1, 0.01));
  });

  test('live Compressor changes keep transport running', () async {
    final dryTrack = track('live-compressor');
    await engine.play(tracks: [dryTrack], fromSeconds: 0);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final before = engine.currentPositionSeconds;

    engine.syncTrackCompressorFx([
      dryTrack.copyWith(
        compressorFx: const TrackCompressorFx(
          enabled: true,
          thresholdDb: -30,
          ratio: 8,
          attackSeconds: 0.005,
          releaseSeconds: 0.1,
          makeupGainDb: 3,
        ),
      ),
    ]);
    final after = engine.currentPositionSeconds;

    expect(engine.isPlaying, isTrue);
    expect(after, greaterThanOrEqualTo(before));
    engine.pause();
  });

  test('offline WAV follows authoritative Track FX order', () async {
    final frameCount = sampleRate * durationSeconds ~/ 1;
    final tone = Float32List(frameCount);
    for (var index = 0; index < frameCount; index++) {
      tone[index] = 0.1 * math.sin(2 * math.pi * 1000 * index / sampleRate);
    }
    final bytes = WavEncoder.encodePcm16(
      channels: [tone, tone],
      sampleRate: sampleRate,
    );
    final decoded = await engine.decode(assetId: 'asset-order', bytes: bytes);
    asset = AudioAsset(
      id: 'asset-order',
      name: 'order.wav',
      extension: 'wav',
      size: bytes.length,
      durationSeconds: decoded.durationSeconds,
      sampleRate: decoded.sampleRate,
      numberOfChannels: decoded.numberOfChannels,
      waveformPeaks: decoded.waveformPeaks,
    );
    const eq = TrackEqFx(
      enabled: true,
      midGainDb: 12,
      midFrequencyHz: 1000,
      midQ: 3,
    );
    const compressor = TrackCompressorFx(
      enabled: true,
      thresholdDb: -35,
      ratio: 20,
      attackSeconds: 0.001,
      releaseSeconds: 0.02,
    );

    final eqThenCompressor = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'eq-then-comp',
          eqFx: eq,
          compressorFx: compressor,
          fxChainOrder: const [
            TrackFxType.eq,
            TrackFxType.compressor,
            TrackFxType.filter,
          ],
        ),
      ])).wavBytes,
    );
    final compressorThenEq = _leftChannelRms(
      (await mixdown.generateWavExport([
        track(
          'comp-then-eq',
          eqFx: eq,
          compressorFx: compressor,
          fxChainOrder: const [
            TrackFxType.compressor,
            TrackFxType.eq,
            TrackFxType.filter,
          ],
        ),
      ])).wavBytes,
    );

    expect(compressorThenEq / eqThenCompressor, greaterThan(1.3));
  });

  test('repeated live Track FX reorder keeps transport running', () async {
    final liveTrack = track(
      'live-order',
      eqFx: const TrackEqFx(enabled: true, midGainDb: 6),
      compressorFx: const TrackCompressorFx(
        enabled: true,
        thresholdDb: -30,
        ratio: 8,
      ),
    );
    await engine.play(tracks: [liveTrack], fromSeconds: 0);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final before = engine.currentPositionSeconds;

    for (var index = 0; index < 24; index++) {
      engine.syncMixer([
        liveTrack.copyWith(
          fxChainOrder: index.isEven
              ? const [
                  TrackFxType.compressor,
                  TrackFxType.filter,
                  TrackFxType.eq,
                ]
              : defaultTrackFxChainOrder,
        ),
      ]);
    }

    expect(engine.isPlaying, isTrue);
    expect(engine.currentPositionSeconds, greaterThanOrEqualTo(before));
    engine.pause();
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
