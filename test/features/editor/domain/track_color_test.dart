import 'package:daw_webapp/features/editor/domain/track_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default track colors rotate deterministically', () {
    expect(defaultTrackColorForIndex(0), TrackColors.purple);
    expect(defaultTrackColorForIndex(1), TrackColors.blue);
    expect(defaultTrackColorForIndex(2), TrackColors.cyan);
    expect(
      defaultTrackColorForIndex(defaultTrackColorRotation.length),
      TrackColors.purple,
    );
  });

  test('custom colors are normalized to fully opaque ARGB', () {
    expect(opaqueTrackColor(0x00123456), 0xFF123456);
    expect(opaqueTrackColor(0x7FABCDEF), 0xFFABCDEF);
  });
}
