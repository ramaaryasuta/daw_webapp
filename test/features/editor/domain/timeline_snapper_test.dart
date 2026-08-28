import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:daw_webapp/features/editor/domain/snap_settings.dart';
import 'package:daw_webapp/features/editor/domain/timeline_snapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineSnapper interval', () {
    test('derives subdivisions from BPM', () {
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.beat,
        ),
        0.5,
      );
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.halfBeat,
        ),
        0.25,
      );
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.quarterBeat,
        ),
        0.125,
      );
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 60,
          subdivision: SnapSubdivision.beat,
        ),
        1,
      );
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 150,
          subdivision: SnapSubdivision.beat,
        ),
        0.4,
      );
    });

    test('derives a bar from the supplied meter', () {
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.bar,
          timeSignature: TimeSignature.threeFour,
        ),
        1.5,
      );
    });

    test('derives beat and bar intervals for literal 6/8', () {
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.beat,
          timeSignature: TimeSignature.sixEight,
        ),
        0.25,
      );
      expect(
        TimelineSnapper.intervalSeconds(
          bpm: 120,
          subdivision: SnapSubdivision.bar,
          timeSignature: TimeSignature.sixEight,
        ),
        1.5,
      );
    });
  });

  group('TimelineSnapper snapTime', () {
    const beatSnap = SnapSettings(subdivision: SnapSubdivision.beat);

    test('uses nearest direct grid index', () {
      expect(
        TimelineSnapper.snapTime(
          candidateSeconds: 3.31,
          bpm: 120,
          settings: beatSnap,
        ),
        3.5,
      );
      expect(
        TimelineSnapper.snapTime(
          candidateSeconds: 3.18,
          bpm: 120,
          settings: beatSnap,
        ),
        3,
      );
    });

    test('keeps quarter-beat positions aligned without accumulation', () {
      const settings = SnapSettings(subdivision: SnapSubdivision.quarterBeat);
      final positions = [
        for (var index = 0; index <= 1000; index++)
          TimelineSnapper.snapTime(
            candidateSeconds: index * 0.125 + 0.001,
            bpm: 120,
            settings: settings,
          ),
      ];

      for (var index = 0; index < positions.length; index++) {
        expect(positions[index], closeTo(index * 0.125, 1e-12));
      }
    });

    test('clamps zero and leaves time free when disabled', () {
      expect(
        TimelineSnapper.snapTime(
          candidateSeconds: -0.2,
          bpm: 120,
          settings: beatSnap,
        ),
        0,
      );
      expect(
        TimelineSnapper.snapTime(
          candidateSeconds: 3.31,
          bpm: 120,
          settings: const SnapSettings(enabled: false),
        ),
        3.31,
      );
    });
  });
}
