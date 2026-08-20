import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineScale', () {
    test('converts between time and pixels without losing timeline time', () {
      const scale = TimelineScale(100);
      const time = Duration(milliseconds: 5500);

      expect(scale.timeToPixels(time), 550);
      expect(scale.pixelsToTime(550), time);
      expect(scale.secondsToPixels(5.5), 550);
      expect(scale.pixelsToSeconds(550), 5.5);
    });

    test('selects readable major intervals as zoom changes', () {
      expect(const TimelineScale(1200).majorTickIntervalSeconds, 0.1);
      expect(const TimelineScale(400).majorTickIntervalSeconds, 0.25);
      expect(const TimelineScale(100).majorTickIntervalSeconds, 1);
      expect(const TimelineScale(20).majorTickIntervalSeconds, 5);
      expect(const TimelineScale(2).majorTickIntervalSeconds, 60);
    });

    test('uses millisecond labels only for sub-second major intervals', () {
      expect(const TimelineScale(400).formatTickLabel(5.5), '00:05.500');
      expect(const TimelineScale(100).formatTickLabel(5), '00:05');
    });

    test('keeps the same timeline time beneath a zoom anchor', () {
      const oldScale = TimelineScale(100);
      const newScale = TimelineScale(200);
      const cursorX = 300.0;
      const oldOffset = 200.0;

      final newOffset = oldScale.scrollOffsetKeepingAnchor(
        newScale: newScale,
        currentScrollOffset: oldOffset,
        viewportX: cursorX,
      );

      final oldTime = oldScale.pixelsToSeconds(oldOffset + cursorX);
      final newTime = newScale.pixelsToSeconds(newOffset + cursorX);

      expect(newOffset, 700);
      expect(newTime, oldTime);
    });

    test('content width separates project duration from viewport width', () {
      const scale = TimelineScale(100);

      expect(
        scale.timelineContentWidth(durationSeconds: 10, viewportWidth: 800),
        1200,
      );
      expect(
        scale.timelineContentWidth(durationSeconds: 2, viewportWidth: 800),
        800,
      );
    });
  });
}
