import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filter defaults are safely bypassed and retain useful parameters', () {
    const filter = TrackFilterFx();

    expect(filter.enabled, isFalse);
    expect(filter.highPass.enabled, isFalse);
    expect(filter.highPass.frequencyHz, defaultHighPassFrequencyHz);
    expect(filter.highPass.q, defaultFilterQ);
    expect(filter.lowPass.enabled, isFalse);
    expect(filter.lowPass.frequencyHz, defaultLowPassFrequencyHz);
    expect(filter.lowPass.q, defaultFilterQ);
  });

  test('filter values clamp to the supported Web Audio range', () {
    const filter = TrackFilterFx();

    final changed = filter.copyWith(
      highPass: filter.highPass.copyWith(frequencyHz: 1, q: 50),
      lowPass: filter.lowPass.copyWith(frequencyHz: 50000, q: 0),
    );

    expect(changed.highPass.frequencyHz, minimumFilterFrequencyHz);
    expect(changed.highPass.q, maximumFilterQ);
    expect(changed.lowPass.frequencyHz, maximumFilterFrequencyHz);
    expect(changed.lowPass.q, minimumFilterQ);
  });

  test('frequency labels stay compact', () {
    expect(formatFilterFrequency(420), '420 Hz');
    expect(formatFilterFrequency(1000), '1 kHz');
    expect(formatFilterFrequency(1250), '1.25 kHz');
    expect(formatFilterFrequency(14200), '14.2 kHz');
  });
}
