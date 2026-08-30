import 'package:daw_webapp/features/editor/domain/track_compressor_fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compressor defaults are safely bypassed and musically useful', () {
    const compressor = TrackCompressorFx();

    expect(compressor.enabled, isFalse);
    expect(compressor.thresholdDb, -18);
    expect(compressor.ratio, 4);
    expect(compressor.attackSeconds, 0.01);
    expect(compressor.releaseSeconds, 0.25);
    expect(compressor.makeupGainDb, 0);
  });

  test('compressor copy clamps every user-controlled parameter', () {
    const compressor = TrackCompressorFx();
    final changed = compressor.copyWith(
      thresholdDb: -100,
      ratio: 40,
      attackSeconds: 0,
      releaseSeconds: 5,
      makeupGainDb: double.nan,
    );

    expect(changed.thresholdDb, minimumCompressorThresholdDb);
    expect(changed.ratio, maximumCompressorRatio);
    expect(changed.attackSeconds, minimumCompressorAttackSeconds);
    expect(changed.releaseSeconds, maximumCompressorReleaseSeconds);
    expect(changed.makeupGainDb, defaultCompressorMakeupGainDb);
  });

  test('compressor values use readable units', () {
    expect(formatCompressorThreshold(-24), '-24.0 dB');
    expect(formatCompressorRatio(4), '4.0:1');
    expect(formatCompressorAttack(0.085), '85 ms');
    expect(formatCompressorRelease(0.25), '250 ms');
    expect(formatCompressorRelease(1.2), '1.20 s');
    expect(formatCompressorMakeup(4.5), '+4.5 dB');
  });
}
