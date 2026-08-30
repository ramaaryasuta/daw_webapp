import 'package:daw_webapp/features/editor/presentation/widgets/daw_interaction_hint.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hint appears after delay and dismisses on pointer down', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: DawInteractionHint(
            data: DawInteractionHints.audioClip,
            child: SizedBox(
              key: ValueKey('hint-target'),
              width: 120,
              height: 40,
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('hint-target'))),
    );
    await tester.pump(const Duration(milliseconds: 599));
    expect(_visibleHint, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_visibleHint, findsOneWidget);

    await mouse.down(
      tester.getCenter(find.byKey(const ValueKey('hint-target'))),
    );
    await tester.pump();
    expect(_visibleHint, findsNothing);
    await mouse.up();
  });

  testWidgets('hint follows focus without making its target focusable', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: DawInteractionHint(
            data: DawInteractionHints.trackName,
            child: TextButton(
              focusNode: focusNode,
              onPressed: () {},
              child: const Text('Track name'),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(
      find.text(DawInteractionHints.trackName.plainText, findRichText: true),
      findsOneWidget,
    );
  });
}

Finder get _visibleHint =>
    find.text(DawInteractionHints.audioClip.plainText, findRichText: true);
