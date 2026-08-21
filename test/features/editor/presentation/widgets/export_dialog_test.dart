import 'dart:async';
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/infrastructure/generated_export.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/export_dialog.dart';
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
    expect(find.text('Regenerate'), findsOneWidget);
    expect(generator.generationCount, 1);
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
