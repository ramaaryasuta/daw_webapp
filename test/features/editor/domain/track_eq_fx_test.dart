import 'package:daw_webapp/features/editor/domain/track_eq_fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EQ defaults are bypassed and flat', () {
    const eq = TrackEqFx();

    expect(eq.enabled, isFalse);
    expect(eq.lowGainDb, 0);
    expect(eq.midGainDb, 0);
    expect(eq.midFrequencyHz, defaultEqMidFrequencyHz);
    expect(eq.midQ, defaultEqMidQ);
    expect(eq.highGainDb, 0);
    expect(eq.isProcessing, isFalse);
  });

  test('EQ copy clamps every user-controlled parameter', () {
    const eq = TrackEqFx();
    final changed = eq.copyWith(
      lowGainDb: -40,
      midGainDb: 40,
      midFrequencyHz: 20,
      midQ: 20,
      highGainDb: double.nan,
    );

    expect(changed.lowGainDb, minimumEqGainDb);
    expect(changed.midGainDb, maximumEqGainDb);
    expect(changed.midFrequencyHz, minimumEqMidFrequencyHz);
    expect(changed.midQ, maximumEqMidQ);
    expect(changed.highGainDb, 0);
  });

  test('EQ values use musician-readable formatting', () {
    expect(formatEqGain(-12), '-12.0 dB');
    expect(formatEqGain(0), '0.0 dB');
    expect(formatEqGain(6.5), '+6.5 dB');
    expect(formatEqFrequency(850), '850 Hz');
    expect(formatEqFrequency(1250), '1.25 kHz');
  });
}
