import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/track_reverb_fx.dart';

class ReverbImpulseResponse {
  const ReverbImpulseResponse({required this.left, required this.right});

  final Float32List left;
  final Float32List right;

  int get length => left.length;
}

/// Builds a deterministic, decorrelated stereo room/hall impulse. The same
/// decay, sample rate, and channel always produce the same samples for live
/// playback and offline export parity.
ReverbImpulseResponse generateReverbImpulseResponse({
  required double sampleRate,
  required double decaySeconds,
}) {
  final safeSampleRate = sampleRate.round().clamp(8000, 192000);
  final safeDecay = clampReverbDecaySeconds(decaySeconds);
  final length = math.max(2, (safeSampleRate * safeDecay).ceil());
  final channels = <Float32List>[];

  for (var channel = 0; channel < 2; channel++) {
    final samples = Float32List(length);
    var random = _XorShift32(
      0x6d2b79f5 ^ safeSampleRate ^ length ^ (channel * 0x1f123bb5),
    );
    var previous1 = 0.0;
    var previous2 = 0.0;
    var previous3 = 0.0;
    for (var frame = 0; frame < length; frame++) {
      final progress = frame / (length - 1);
      final noise = random.nextSignedDouble();
      // A short decorrelating diffuser makes the energy dense while avoiding
      // the brittle sound of independent white-noise samples.
      final diffuse =
          noise * 0.58 + previous1 * 0.24 - previous2 * 0.11 + previous3 * 0.07;
      previous3 = previous2;
      previous2 = previous1;
      previous1 = noise;
      final envelope =
          math.pow(1 - progress, 1.55).toDouble() * math.exp(-2.1 * progress);
      final tailFadeFrames = math.max(1, (safeSampleRate * 0.025).round());
      final fade = frame >= length - tailFadeFrames
          ? (length - 1 - frame) / tailFadeFrames
          : 1.0;
      samples[frame] = diffuse * envelope * fade * 0.34;
    }

    // Uneven, channel-offset reflections reinforce the early room character
    // without introducing a repeating echo pattern.
    final reflectionMs = channel == 0
        ? const [5.3, 11.7, 19.1, 31.9, 47.3, 68.9]
        : const [6.1, 13.9, 22.7, 35.3, 51.1, 73.7];
    for (var index = 0; index < reflectionMs.length; index++) {
      final frame = (reflectionMs[index] * safeSampleRate / 1000).round();
      if (frame < length) {
        final polarity = (index + channel).isEven ? 1.0 : -1.0;
        samples[frame] += polarity * 0.26 / (1 + index * 0.52);
      }
    }
    channels.add(samples);
  }

  for (final samples in channels) {
    var energy = 0.0;
    var peak = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
      peak = math.max(peak, sample.abs());
    }
    if (energy > 0) {
      // Keep convolution gain controlled for sustained signals while retaining
      // enough early-reflection level to sound present at moderate Mix values.
      final energyScale = 0.9 / math.sqrt(energy);
      final peakScale = peak > 0 ? 0.82 / peak : 1.0;
      final scale = math.min(energyScale, peakScale);
      for (var index = 0; index < samples.length; index++) {
        samples[index] *= scale;
      }
    }
  }
  return ReverbImpulseResponse(left: channels[0], right: channels[1]);
}

class _XorShift32 {
  _XorShift32(int seed) : _state = seed == 0 ? 0x9e3779b9 : seed;

  int _state;

  double nextSignedDouble() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >>> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return (_state / 0xffffffff) * 2 - 1;
  }
}
