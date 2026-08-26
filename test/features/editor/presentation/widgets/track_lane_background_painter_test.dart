import 'package:daw_webapp/features/editor/presentation/widgets/track_lane_background_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const painter = TrackLaneBackgroundPainter(
    baseColor: Colors.black,
    alternateColor: Color(0xFF111111),
    separatorColor: Colors.grey,
    rowHeight: 110,
    scrollOffset: 0,
    devicePixelRatio: 1,
  );

  test('fills the viewport with visual lanes using the shared row height', () {
    final lanes = painter.lanesForSize(const Size(800, 245)).toList();

    expect(lanes, hasLength(3));
    expect(lanes[0].index, 0);
    expect(lanes[0].rect, const Rect.fromLTWH(0, 0, 800, 110));
    expect(lanes[2].rect.bottom, greaterThanOrEqualTo(245));
  });

  test('aligns painted lanes with real rows while vertically scrolled', () {
    const scrolled = TrackLaneBackgroundPainter(
      baseColor: Colors.black,
      alternateColor: Color(0xFF111111),
      separatorColor: Colors.grey,
      rowHeight: 110,
      scrollOffset: 165,
      devicePixelRatio: 1,
    );
    final lanes = scrolled.lanesForSize(const Size(800, 220)).toList();

    expect(lanes.first.index, 1);
    expect(lanes.first.rect.top, -55);
    expect(lanes[1].index, 2);
    expect(lanes[1].rect.top, 55);
    expect(lanes.last.rect.bottom, greaterThanOrEqualTo(220));
  });
}
