import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_eq_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_compressor_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_delay_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_fx_chain.dart';
import 'package:daw_webapp/features/editor/domain/track_reverb_fx.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/project_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> baseTrackJson() => {
    'id': 'track-1',
    'order': 0,
    'name': 'Vocals',
    'colorArgb': 0xff6750a4,
    'volumeDb': -3,
    'mute': false,
    'solo': false,
    'pan': 0.25,
  };

  test('older track metadata defaults Filter FX to bypassed', () {
    final track = ProjectTrackDto.fromJson(baseTrackJson());

    expect(track.filterFx, const TrackFilterFx());
    expect(track.filterFx.isProcessing, isFalse);
    expect(track.eqFx, const TrackEqFx());
    expect(track.eqFx.isProcessing, isFalse);
    expect(track.compressorFx, const TrackCompressorFx());
    expect(track.delayFx, const TrackDelayFx());
    expect(track.reverbFx, const TrackReverbFx());
    expect(track.fxChainOrder, defaultTrackFxChainOrder);
  });

  test('Filter FX metadata round-trips all authoritative values', () {
    final original = ProjectTrackDto(
      id: 'track-1',
      order: 0,
      name: 'Vocals',
      colorArgb: 0xff6750a4,
      volumeDb: -3,
      muted: false,
      solo: false,
      pan: 0.25,
      filterFx: const TrackFilterFx(
        enabled: true,
        highPass: TrackFilterModule(enabled: true, frequencyHz: 120, q: 1.2),
        lowPass: TrackFilterModule(enabled: true, frequencyHz: 14200, q: 2.4),
      ),
      eqFx: const TrackEqFx(
        enabled: true,
        lowGainDb: 3.5,
        midGainDb: -4,
        midFrequencyHz: 1450,
        midQ: 2.2,
        highGainDb: 1.5,
      ),
      compressorFx: const TrackCompressorFx(
        enabled: true,
        thresholdDb: -24,
        ratio: 6,
        attackSeconds: 0.02,
        releaseSeconds: 0.4,
        makeupGainDb: 3,
      ),
      delayFx: const TrackDelayFx(
        enabled: true,
        syncToBpm: true,
        timeSeconds: 0.72,
        syncDivision: DelaySyncDivision.dottedEighth,
        feedback: 0.62,
        mix: 0.4,
      ),
      reverbFx: const TrackReverbFx(
        enabled: true,
        preDelaySeconds: 0.08,
        decaySeconds: 4.2,
        dampingHz: 5200,
        mix: 0.45,
      ),
      fxChainOrder: const [
        TrackFxType.compressor,
        TrackFxType.delay,
        TrackFxType.filter,
        TrackFxType.eq,
        TrackFxType.reverb,
      ],
    );

    final restored = ProjectTrackDto.fromJson(original.toJson());

    expect(restored.filterFx, original.filterFx);
    expect(restored.eqFx, original.eqFx);
    expect(restored.compressorFx, original.compressorFx);
    expect(restored.delayFx, original.delayFx);
    expect(restored.reverbFx, original.reverbFx);
    expect(restored.fxChainOrder, original.fxChainOrder);
    expect(original.toJson()['fxChainOrder'], [
      'compressor',
      'delay',
      'filter',
      'eq',
      'reverb',
    ]);
  });

  test('legacy three-effect order appends bypassed Delay and Reverb', () {
    final restored = ProjectTrackDto.fromJson({
      ...baseTrackJson(),
      'fxChainOrder': ['compressor', 'filter', 'eq'],
    });

    expect(restored.delayFx, const TrackDelayFx());
    expect(restored.fxChainOrder, const [
      TrackFxType.compressor,
      TrackFxType.filter,
      TrackFxType.eq,
      TrackFxType.delay,
      TrackFxType.reverb,
    ]);
  });

  test('existing four-effect order appends bypassed Reverb at the end', () {
    final restored = ProjectTrackDto.fromJson({
      ...baseTrackJson(),
      'fxChainOrder': ['delay', 'compressor', 'filter', 'eq'],
    });

    expect(restored.reverbFx, const TrackReverbFx());
    expect(restored.fxChainOrder, const [
      TrackFxType.delay,
      TrackFxType.compressor,
      TrackFxType.filter,
      TrackFxType.eq,
      TrackFxType.reverb,
    ]);
  });

  test('FX order rejects missing, duplicate, or unknown effects', () {
    expect(
      () => ProjectTrackDto.fromJson({
        ...baseTrackJson(),
        'fxChainOrder': ['filter', 'filter', 'compressor'],
      }),
      throwsA(isA<FlaudioProjectException>()),
    );
    expect(
      () => ProjectTrackDto.fromJson({
        ...baseTrackJson(),
        'fxChainOrder': ['filter', 'eq', 'reverb'],
      }),
      throwsA(isA<FlaudioProjectException>()),
    );
  });
}
