import 'dart:math' as math;

int calculateOfflineFrameCount({
  required double durationSeconds,
  required double sampleRate,
}) {
  if (!durationSeconds.isFinite || durationSeconds <= 0) {
    throw ArgumentError.value(
      durationSeconds,
      'durationSeconds',
      'Must be finite and positive.',
    );
  }
  if (!sampleRate.isFinite || sampleRate <= 0) {
    throw ArgumentError.value(
      sampleRate,
      'sampleRate',
      'Must be finite and positive.',
    );
  }

  return math.max(1, (durationSeconds * sampleRate).ceil());
}

/// Validates and returns the browser's rendered `AudioBuffer.duration`.
///
/// All duration values use fractional seconds. Invalid rendered metadata is a
/// generation failure rather than a value the UI should normalize to zero.
double validateRenderedDurationSeconds({
  required double durationSeconds,
  required int frameCount,
  required double sampleRate,
  required int channelCount,
}) {
  if (frameCount <= 0) {
    throw ArgumentError.value(frameCount, 'frameCount', 'Must be positive.');
  }
  if (!sampleRate.isFinite || sampleRate <= 0) {
    throw ArgumentError.value(
      sampleRate,
      'sampleRate',
      'Must be finite and positive.',
    );
  }
  if (channelCount <= 0) {
    throw ArgumentError.value(
      channelCount,
      'channelCount',
      'Must be positive.',
    );
  }
  if (!durationSeconds.isFinite || durationSeconds <= 0) {
    throw ArgumentError.value(
      durationSeconds,
      'durationSeconds',
      'Must be finite and positive.',
    );
  }

  final frameDurationSeconds = frameCount / sampleRate;
  final oneFrameSeconds = 1 / sampleRate;
  if ((durationSeconds - frameDurationSeconds).abs() > oneFrameSeconds) {
    throw ArgumentError.value(
      durationSeconds,
      'durationSeconds',
      'Must agree with the rendered frame length.',
    );
  }

  return durationSeconds;
}
