import 'package:daw_webapp/features/editor/presentation/widgets/delete_track_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLauncher(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDeleteTrackConfirmation(context, clipCount: 3),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('non-empty track confirmation is compact and cancellable', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Track?'), findsOneWidget);
    expect(find.textContaining('3 audio clips'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete Track and Clips'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Track?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
