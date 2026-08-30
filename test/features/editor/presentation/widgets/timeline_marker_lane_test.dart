import 'package:daw_webapp/features/editor/domain/timeline_marker.dart';
import 'package:daw_webapp/features/editor/domain/timeline_scale.dart';
import 'package:daw_webapp/features/editor/domain/timeline_section.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/daw_interaction_hint.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/timeline_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const metrics = TimelineGridMetrics(
    transform: TimelineTransform(scale: TimelineScale(100)),
  );
  const marker = TimelineMarker(
    id: 'marker-1',
    timeSeconds: 2,
    name: 'Verse',
    colorArgb: 0xFF527AC2,
  );
  const section = TimelineSection(
    id: 'section-1',
    startTime: 1,
    endTime: 3,
    name: 'Intro',
    colorArgb: 0xFF43A047,
  );

  testWidgets('dragging empty lane shows preview and commits one section', (
    tester,
  ) async {
    final added = <(double, double)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              onSeek: (_) {},
              onAddSection: (start, end) => added.add((start, end)),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byTooltip(DawInteractionHints.sectionLane.plainText),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('timeline-marker-lane')),
      const Offset(150, 0),
    );
    await tester.pump();

    expect(added, hasLength(1));
    expect(added.single.$2 - added.single.$1, closeTo(1.5, .05));
  });

  testWidgets('selected section exposes handles and opens properties', (
    tester,
  ) async {
    double? seekTime;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              sections: const [section],
              selectedSectionId: section.id,
              onSeek: (time) => seekTime = time,
              onSelectSection: (_) {},
              onSectionRename: (_, _) {},
              onSectionColorSelected: (_, _) {},
              onSectionDelete: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('section-left-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-right-handle')), findsOneWidget);
    expect(
      find.byTooltip(DawInteractionHints.section.plainText),
      findsOneWidget,
    );
    await tester.tap(find.text('Intro'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(seekTime, section.startTime);
    await tester.tap(find.text('Intro'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Intro'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('section-properties-popover')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('section-name-field')), findsOneWidget);
  });

  testWidgets(
    'empty marker lane double-click creates at shared timeline time',
    (tester) async {
      double? addedAt;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: TimelineRuler(
                playheadSeconds: 0,
                gridMetrics: metrics,
                onSeek: (_) {},
                onAddMarker: (time) => addedAt = time,
              ),
            ),
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(TimelineRuler));
      final lanePoint = origin + const Offset(237, 42);
      await tester.tapAt(lanePoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(lanePoint);
      await tester.pump(const Duration(milliseconds: 350));

      expect(addedAt, closeTo(2.37, 1e-12));
    },
  );

  testWidgets('marker click selects and seeks without adding a marker', (
    tester,
  ) async {
    String? selectedId;
    double? seekTime;
    var addCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              markers: const [marker],
              onSeek: (_) {},
              onMarkerSeek: (time) => seekTime = time,
              onSelectMarker: (id) => selectedId = id,
              onAddMarker: (_) => addCount++,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byTooltip(DawInteractionHints.marker.plainText),
      findsOneWidget,
    );

    await tester.tap(find.text('Verse'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(selectedId, marker.id);
    expect(seekTime, marker.timeSeconds);
    expect(addCount, 0);
  });

  testWidgets('one horizontal drag emits live previews and one completion', (
    tester,
  ) async {
    var startCount = 0;
    var endCount = 0;
    final previews = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              markers: const [marker],
              onSeek: (_) {},
              onMarkerMoveStart: (_) => startCount++,
              onMarkerMovePreview: (_, time) => previews.add(time),
              onMarkerMoveEnd: (_) => endCount++,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('Verse'), const Offset(75, 0));
    await tester.pump(const Duration(milliseconds: 50));

    expect(startCount, 1);
    expect(endCount, 1);
    expect(previews, isNotEmpty);
    expect(previews.last, closeTo(2.75, 0.05));
  });

  testWidgets('double-clicking an existing marker opens compact properties', (
    tester,
  ) async {
    var addCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: TimelineRuler(
              playheadSeconds: 0,
              gridMetrics: metrics,
              markers: const [marker],
              onSeek: (_) {},
              onAddMarker: (_) => addCount++,
              onSelectMarker: (_) {},
              onMarkerRename: (_, _) {},
              onMarkerColorSelected: (_, _) {},
              onMarkerDelete: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Verse'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Verse'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('marker-properties-popover')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('marker-name-field')), findsOneWidget);
    expect(find.text('Delete Marker'), findsOneWidget);
    expect(addCount, 0);
  });
}
