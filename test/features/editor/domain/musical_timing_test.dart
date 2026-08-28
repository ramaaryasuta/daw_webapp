import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MusicalTiming', () {
    test('maps 120 BPM in 4/4 from timeline zero', () {
      final timing = MusicalTiming(bpm: 120);

      expect(timing.beatDurationSeconds, 0.5);
      expect(timing.barDurationSeconds, 2);
      expect(timing.beatTimeSeconds(0), 0);
      expect(timing.beatTimeSeconds(1), 0.5);
      expect(timing.beatTimeSeconds(2), 1);
      expect(timing.beatTimeSeconds(3), 1.5);
      expect(timing.beatTimeSeconds(4), 2);
      expect(timing.positionAtBeatIndex(0).label, '1:1');
      expect(timing.positionAtBeatIndex(3).label, '1:4');
      expect(timing.positionAtBeatIndex(4).label, '2:1');
    });

    test('responds to BPM changes without changing the origin', () {
      final slow = MusicalTiming(bpm: 60);
      final fast = MusicalTiming(bpm: 150);

      expect(slow.beatDurationSeconds, 1);
      expect(slow.barDurationSeconds, 4);
      expect(fast.beatDurationSeconds, closeTo(0.4, 1e-12));
      expect(fast.barDurationSeconds, closeTo(1.6, 1e-12));
      expect(slow.positionAtTime(0).label, '1:1');
      expect(fast.positionAtTime(0).label, '1:1');
    });

    test('converts positions and detects downbeats using the meter', () {
      final timing = MusicalTiming(
        bpm: 120,
        timeSignature: TimeSignature.threeFour,
      );

      expect(
        timing.musicalPositionToTime(const MusicalPosition(bar: 3, beat: 2)),
        3.5,
      );
      expect(timing.isDownbeat(0), isTrue);
      expect(timing.isDownbeat(3), isTrue);
      expect(timing.isDownbeat(4), isFalse);
    });

    test('uses the denominator to derive literal beat duration', () {
      final threeFour = MusicalTiming(
        bpm: 120,
        timeSignature: TimeSignature.threeFour,
      );
      final sixEight = MusicalTiming(
        bpm: 120,
        timeSignature: TimeSignature.sixEight,
      );

      expect(threeFour.quarterNoteSeconds, 0.5);
      expect(threeFour.beatSeconds, 0.5);
      expect(threeFour.barSeconds, 1.5);
      expect(threeFour.positionAtBeatIndex(3).label, '2:1');
      expect(sixEight.quarterNoteSeconds, 0.5);
      expect(sixEight.beatSeconds, 0.25);
      expect(sixEight.barSeconds, 1.5);
      expect(sixEight.positionAtBeatIndex(5).label, '1:6');
      expect(sixEight.positionAtBeatIndex(6).label, '2:1');
      expect(sixEight.isDownbeat(0), isTrue);
      expect(sixEight.isDownbeat(5), isFalse);
      expect(sixEight.isDownbeat(6), isTrue);
    });

    test('calculates visible beat starts directly by index', () {
      final timing = MusicalTiming(bpm: 120);

      expect(timing.firstBeatIndexAtOrAfter(5000.01), 10001);
      expect(timing.beatTimeSeconds(10001), 5000.5);
    });
  });
}
