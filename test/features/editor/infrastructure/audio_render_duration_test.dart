import 'package:daw_webapp/features/editor/infrastructure/audio_render_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateOfflineFrameCount', () {
    test('uses the complete fractional duration before rounding', () {
      expect(
        calculateOfflineFrameCount(durationSeconds: 0.75, sampleRate: 48000),
        36000,
      );
    });

    test('rounds partial frames up', () {
      expect(
        calculateOfflineFrameCount(
          durationSeconds: 1 / 48000 / 2,
          sampleRate: 48000,
        ),
        1,
      );
    });
  });

  group('validateRenderedDurationSeconds', () {
    test('prefers a valid AudioBuffer duration', () {
      expect(
        validateRenderedDurationSeconds(
          durationSeconds: 5.00001,
          frameCount: 240001,
          sampleRate: 48000,
          channelCount: 2,
        ),
        5.00001,
      );
    });

    test('rejects zero duration instead of silently replacing it', () {
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: 0,
          frameCount: 240000,
          sampleRate: 48000,
          channelCount: 2,
        ),
        throwsArgumentError,
      );
    });

    test('rejects duration that conflicts with rendered frames', () {
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: 0.00001,
          frameCount: 240000,
          sampleRate: 48000,
          channelCount: 2,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite duration', () {
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: double.nan,
          frameCount: 36000,
          sampleRate: 48000,
          channelCount: 2,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid rendered buffer metrics', () {
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: 0.75,
          frameCount: 0,
          sampleRate: 48000,
          channelCount: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: 0.75,
          frameCount: 36000,
          sampleRate: 0,
          channelCount: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => validateRenderedDurationSeconds(
          durationSeconds: 0.75,
          frameCount: 36000,
          sampleRate: 48000,
          channelCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
