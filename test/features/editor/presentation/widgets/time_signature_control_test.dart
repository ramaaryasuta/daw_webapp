import 'package:daw_webapp/features/editor/domain/musical_timing.dart';
import 'package:daw_webapp/features/editor/presentation/widgets/time_signature_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows supported signatures and reports the selection', (
    tester,
  ) async {
    TimeSignature? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TimeSignatureButton(
              selected: TimeSignature.commonTime,
              onSelected: (value) => changed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('4/4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('time-signature-control')));
    await tester.pumpAndSettle();

    expect(find.text('TIME SIGNATURE'), findsOneWidget);
    expect(find.text('Common time'), findsOneWidget);
    expect(find.text('Triple meter'), findsOneWidget);
    expect(find.text('Compound meter'), findsOneWidget);
    expect(find.byKey(const ValueKey('time-signature-4/4')), findsOneWidget);
    expect(find.byKey(const ValueKey('time-signature-3/4')), findsOneWidget);
    expect(find.byKey(const ValueKey('time-signature-6/8')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('time-signature-3/4')));
    await tester.pumpAndSettle();

    expect(changed, TimeSignature.threeFour);
  });

  testWidgets('uses a subtle active trigger state while the menu is open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TimeSignatureButton(
              selected: TimeSignature.commonTime,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('time-signature-trigger-surface'),
    );
    final before = tester.widget<AnimatedContainer>(surface).decoration;

    await tester.tap(find.byKey(const ValueKey('time-signature-control')));
    await tester.pump();

    final after = tester.widget<AnimatedContainer>(surface).decoration;
    expect(after, isNot(before));
    expect(find.byType(PopupMenuItem<TimeSignature>), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
