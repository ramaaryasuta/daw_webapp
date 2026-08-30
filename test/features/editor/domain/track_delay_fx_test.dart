import 'package:daw_webapp/features/editor/domain/track_delay_fx.dart';
import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync divisions use quarter-note BPM independent of time signature', () {
    expect(delayTimeForDivision(120, DelaySyncDivision.quarter), 0.5);
    expect(delayTimeForDivision(120, DelaySyncDivision.eighth), 0.25);
    expect(delayTimeForDivision(120, DelaySyncDivision.sixteenth), 0.125);
    expect(delayTimeForDivision(120, DelaySyncDivision.dottedEighth), 0.375);
    expect(delayTimeForDivision(120, DelaySyncDivision.dottedQuarter), 0.75);
    expect(
      MusicalTiming(
        bpm: 120,
        timeSignature: TimeSignature.sixEight,
      ).quarterNoteSeconds,
      delayTimeForDivision(120, DelaySyncDivision.quarter),
    );
  });

  test('feedback is safe and tail estimate is bounded', () {
    expect(clampDelayFeedback(double.nan), defaultDelayFeedback);
    expect(clampDelayFeedback(double.infinity), defaultDelayFeedback);
    expect(clampDelayFeedback(-1), 0);
    expect(clampDelayFeedback(1), maximumDelayFeedback);
    expect(
      estimateDelayTailSeconds(
        const TrackDelayFx(enabled: true, feedback: 0.9, mix: 1),
        120,
      ),
      maximumDelayTailSeconds,
    );
    expect(
      estimateDelayTailSeconds(
        const TrackDelayFx(enabled: true, feedback: 0, mix: 1),
        120,
      ),
      0,
    );
  });

  test('equal-power mix has exact dry and wet endpoints', () {
    expect(delayDryGain(0), 1);
    expect(delayWetGain(0), 0);
    expect(delayDryGain(1), closeTo(0, 1e-12));
    expect(delayWetGain(1), 1);
  });
}
