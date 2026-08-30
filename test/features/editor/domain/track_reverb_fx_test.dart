import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_delay_fx.dart';
import 'package:daw_webapp/features/editor/domain/track_reverb_fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults, clamping, crossfade, and formatting are stable', () {
    const reverb = TrackReverbFx();

    expect(reverb.enabled, isFalse);
    expect(reverb.preDelaySeconds, 0.020);
    expect(reverb.decaySeconds, 1.8);
    expect(reverb.dampingHz, 8000);
    expect(reverb.mix, 0.20);
    expect(reverbDryGain(0), 1);
    expect(reverbWetGain(0), 0);
    expect(reverbDryGain(1), closeTo(0, 1e-12));
    expect(reverbWetGain(1), 1);
    expect(formatReverbPreDelay(0.125), '125 ms');
    expect(formatReverbDecay(6), '6.0 s');
    expect(formatReverbDamping(3500), '3.5 kHz');
    expect(formatReverbMix(0.65), '65%');

    final clamped = reverb.copyWith(
      preDelaySeconds: 9,
      decaySeconds: 99,
      dampingHz: 100,
      mix: -1,
    );
    expect(clamped.preDelaySeconds, maximumReverbPreDelaySeconds);
    expect(clamped.decaySeconds, maximumReverbDecaySeconds);
    expect(clamped.dampingHz, minimumReverbDampingHz);
    expect(clamped.mix, minimumReverbMix);
  });

  test('render allowance combines Delay and Reverb with a finite cap', () {
    const track = DawTrack(
      id: 'track-1',
      name: 'Tail',
      clips: [],
      delayFx: TrackDelayFx(
        enabled: true,
        timeSeconds: 2,
        feedback: 0.9,
        mix: 0.5,
      ),
      reverbFx: TrackReverbFx(
        enabled: true,
        preDelaySeconds: 0.2,
        decaySeconds: 10,
        mix: 0.5,
      ),
    );

    expect(
      calculateProjectRenderDurationSeconds([track], bpm: 120),
      maximumCombinedTrackFxTailSeconds,
    );
  });
}
