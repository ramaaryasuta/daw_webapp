import 'package:daw_webapp/features/editor/domain/timeline_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith preserves stable identity and duration metadata', () {
    const section = TimelineSection(
      id: 'section-7',
      startTime: 4,
      endTime: 12,
      name: 'Verse',
      colorArgb: 0xff527ac2,
    );

    final moved = section.copyWith(startTime: 6, endTime: 14);

    expect(moved.id, section.id);
    expect(moved.duration, section.duration);
    expect(moved.name, section.name);
    expect(moved.colorArgb, section.colorArgb);
  });
}
