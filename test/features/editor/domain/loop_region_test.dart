import 'package:daw_webapp/features/editor/domain/loop_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes forward and backward selections identically', () {
    final forward = LoopRegion.normalized(firstSeconds: 4, secondSeconds: 8);
    final backward = LoopRegion.normalized(firstSeconds: 8, secondSeconds: 4);

    expect(backward, forward);
    expect(forward.startSeconds, 4);
    expect(forward.endSeconds, 8);
    expect(forward.contains(4), isTrue);
    expect(forward.contains(8), isFalse);
  });

  test('enforces the named non-zero minimum in either direction', () {
    final forward = LoopRegion.normalized(firstSeconds: 2, secondSeconds: 2);
    final backward = LoopRegion.normalized(
      firstSeconds: 0.02,
      secondSeconds: 0,
    );

    expect(forward.durationSeconds, closeTo(minimumLoopDurationSeconds, 1e-12));
    expect(backward.startSeconds, 0);
    expect(
      backward.durationSeconds,
      closeTo(minimumLoopDurationSeconds, 1e-12),
    );
  });

  test('uses a smaller authoritative snap interval when supplied', () {
    final region = LoopRegion.normalized(
      firstSeconds: 1,
      secondSeconds: 1,
      minimumDurationSeconds: 0.025,
    );

    expect(region.startSeconds, 1);
    expect(region.endSeconds, closeTo(1.025, 1e-12));
  });
}
