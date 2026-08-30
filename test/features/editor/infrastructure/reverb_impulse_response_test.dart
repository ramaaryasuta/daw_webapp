import 'package:daw_webapp/features/editor/infrastructure/reverb_impulse_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('procedural stereo IR is deterministic, diffuse, and bounded', () {
    final first = generateReverbImpulseResponse(
      sampleRate: 12000,
      decaySeconds: 0.5,
    );
    final second = generateReverbImpulseResponse(
      sampleRate: 12000,
      decaySeconds: 0.5,
    );

    expect(first.length, 6000);
    expect(first.left, orderedEquals(second.left));
    expect(first.right, orderedEquals(second.right));
    expect(first.left, isNot(orderedEquals(first.right)));
    expect(first.left.where((sample) => sample != 0).length, greaterThan(5900));
    expect(
      first.left.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b),
      lessThanOrEqualTo(0.82),
    );
    expect(first.left.last, 0);
    expect(first.right.last, 0);
  });
}
