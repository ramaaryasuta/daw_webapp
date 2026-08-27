import 'package:daw_webapp/features/editor/domain/timeline_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores stable project metadata without pixel coordinates', () {
    const marker = TimelineMarker(
      id: 'marker-7',
      timeSeconds: 12.5,
      name: 'Chorus',
      colorArgb: 0xFFB65C5C,
    );

    final moved = marker.copyWith(timeSeconds: 18, name: 'Drop');

    expect(moved.id, marker.id);
    expect(moved.timeSeconds, 18);
    expect(moved.name, 'Drop');
    expect(moved.colorArgb, marker.colorArgb);
  });
}
