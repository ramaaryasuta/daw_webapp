import 'package:daw_webapp/features/editor/presentation/widgets/snap_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the default resolution and toggles snap off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: SnapControl())),
        ),
      ),
    );

    expect(find.text('1/4 Beat'), findsOneWidget);
    expect(find.byIcon(Icons.grid_4x4), findsOneWidget);

    await tester.tap(find.byTooltip('Disable Snap'));
    await tester.pump();

    expect(find.text('Off - 1/4 Beat'), findsOneWidget);
    expect(find.byIcon(Icons.grid_off), findsOneWidget);
  });

  testWidgets('offers and displays every musical resolution', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: SnapControl())),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Snap resolution'));
    await tester.pumpAndSettle();

    for (final label in [
      '1 Bar',
      '1 Beat',
      '1/2 Beat',
      '1/4 Beat',
      '1/8 Beat',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('1 Beat').last);
    await tester.pumpAndSettle();

    expect(find.text('1 Beat'), findsOneWidget);
  });
}
