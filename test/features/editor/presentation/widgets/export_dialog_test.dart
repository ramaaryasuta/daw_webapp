import 'dart:async';
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/infrastructure/generated_export.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/export_dialog.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/export_studio_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens idle and generates only after the button is pressed', (
    tester,
  ) async {
    final generator = _ControllableExportGenerator();
    var snapshotCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () {
              snapshotCount++;
              return const <DawTrack>[];
            },
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );

    expect(find.text('Generate Export'), findsOneWidget);
    expect(find.text('Generating export...'), findsNothing);
    expect(find.textContaining('00:00'), findsNothing);
    expect(generator.generationCount, 0);
    expect(snapshotCount, 0);

    await tester.tap(find.text('Generate Export'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Generating export...'), findsOneWidget);
    expect(find.text('Generating...'), findsOneWidget);
    expect(find.text('RENDER'), findsOneWidget);
    expect(find.text('PREPARE'), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
    expect(generator.generationCount, 1);
    expect(snapshotCount, 1);

    final generatingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generating...'),
    );
    expect(generatingButton.onPressed, isNull);

    generator.fail();
    await tester.pumpAndSettle();

    expect(find.text('Unable to generate export.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
  });

  testWidgets('shows generated duration only in ready state', (tester) async {
    final generator = _ImmediateExportGenerator(
      GeneratedExport(
        wavBytes: Uint8List(44),
        durationSeconds: 0.75,
        sampleRate: 48000,
        channelCount: 2,
        fileName: 'test.wav',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () => const <DawTrack>[],
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );

    expect(find.text('00:00.750'), findsNothing);

    await tester.tap(find.text('Generate Export'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Ready to export'), findsOneWidget);
    expect(find.text('00:00.750'), findsNWidgets(2));
    expect(find.text('Download WAV'), findsOneWidget);
    expect(find.text('Edit Settings'), findsOneWidget);
    expect(generator.generationCount, 1);
  });

  testWidgets('advanced metadata uses progressive disclosure', (tester) async {
    final generator = _ControllableExportGenerator();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () => const <DawTrack>[],
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('ADVANCED'));
    await tester.tap(find.byKey(const ValueKey('export-format-mp3')));
    await tester.pumpAndSettle();

    expect(find.text('METADATA'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Album'), findsOneWidget);
    expect(find.text('Year'), findsNothing);
    expect(find.text('Comment'), findsNothing);

    final metadataFields = find.descendant(
      of: find.byType(ExportMetadataSection),
      matching: find.byType(TextField),
    );
    expect(metadataFields, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getSize(metadataFields.at(index)).height,
        inInclusiveRange(36, 40),
      );
    }
    expect(
      tester.getTopLeft(metadataFields.at(0)).dy -
          tester.getBottomLeft(find.text('Title')).dy,
      closeTo(6, 1),
    );
    expect(
      tester.getTopLeft(find.text('Artist')).dy -
          tester.getBottomLeft(metadataFields.at(0)).dy,
      closeTo(12, 1),
    );
    final moreTagsRow = find.ancestor(
      of: find.text('MORE TAGS'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getTopLeft(moreTagsRow).dy -
          tester.getBottomLeft(metadataFields.at(2)).dy,
      closeTo(12, 1),
    );

    await tester.scrollUntilVisible(
      find.text('MORE TAGS'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('MORE TAGS'));
    await tester.pumpAndSettle();

    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Genre'), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
  });

  testWidgets('Edit Settings preserves the generated result until changed', (
    tester,
  ) async {
    final generator = _ImmediateExportGenerator(
      GeneratedExport(
        wavBytes: Uint8List(44),
        durationSeconds: 1,
        sampleRate: 48000,
        channelCount: 2,
        fileName: 'cached.wav',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () => const <DawTrack>[],
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );
    final initialDialogSize = tester.getSize(find.byType(Dialog));

    await tester.tap(find.text('Generate Export'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Dialog)), initialDialogSize);

    await tester.tap(find.text('Edit Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Back to Export'), findsOneWidget);

    await tester.tap(find.text('Back to Export'));
    await tester.pumpAndSettle();
    expect(find.text('Download WAV'), findsOneWidget);
    expect(generator.generationCount, 1);
  });

  testWidgets('narrow layout stacks cleanly with long file and metadata text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final generator = _ControllableExportGenerator();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () => const <DawTrack>[],
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('export-file-name')),
      'A very long export filename that should remain bounded in the studio',
    );
    await tester.tap(find.text('ADVANCED'));
    await tester.tap(find.byKey(const ValueKey('export-format-mp3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('MORE TAGS'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('MORE TAGS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an invalid generated duration', (tester) async {
    final generator = _ImmediateExportGenerator(
      GeneratedExport(
        wavBytes: Uint8List(44),
        durationSeconds: 0,
        sampleRate: 48000,
        channelCount: 2,
        fileName: 'invalid.wav',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            createTracksSnapshot: () => const <DawTrack>[],
            exportGenerator: generator,
            onPreviewWillPlay: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Generate Export'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to generate export.'), findsOneWidget);
    expect(find.text('Ready to export'), findsNothing);
    expect(find.textContaining('00:00'), findsNothing);
  });
}

class _ControllableExportGenerator implements AudioExportGenerator {
  final Completer<GeneratedExport> _completer = Completer<GeneratedExport>();
  int generationCount = 0;

  @override
  Future<GeneratedExport> generateWavExport(List<DawTrack> tracks) {
    generationCount++;
    return _completer.future;
  }

  void fail() {
    _completer.completeError(StateError('Test failure.'));
  }
}

class _ImmediateExportGenerator implements AudioExportGenerator {
  _ImmediateExportGenerator(this.result);

  final GeneratedExport result;
  int generationCount = 0;

  @override
  Future<GeneratedExport> generateWavExport(List<DawTrack> tracks) async {
    generationCount++;
    return result;
  }
}
