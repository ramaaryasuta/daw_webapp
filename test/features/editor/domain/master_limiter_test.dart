import 'package:daw_webapp/features/editor/domain/master_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings clamp invalid and out-of-range values safely', () {
    final settings = const MasterLimiterSettings().copyWith(
      thresholdDb: double.nan,
      ceilingDb: 4,
      releaseSeconds: double.infinity,
    );

    expect(settings.thresholdDb, defaultMasterLimiterThresholdDb);
    expect(settings.ceilingDb, maximumMasterLimiterCeilingDb);
    expect(settings.releaseSeconds, defaultMasterLimiterReleaseSeconds);
  });

  test('ceiling curve is symmetric and never exceeds ceiling', () {
    final curve = createMasterLimiterCeilingCurve(-1, length: 101);
    final ceiling = masterLimiterCeilingLinear(-1);

    expect(curve.first, closeTo(-ceiling, 0.000001));
    expect(curve.last, closeTo(ceiling, 0.000001));
    expect(curve[50], closeTo(0, 0.000001));
    expect(curve.every((sample) => sample.abs() <= ceiling + 0.000001), isTrue);
  });
}
