@TestOn('browser')
library;

import 'package:daw_webapp/features/editor/application/editor_controller.dart';
import 'package:daw_webapp/features/editor/presentation/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Back to Main Page leaves a clean editor immediately', (
    tester,
  ) async {
    final harness = await _pumpEditor(tester);
    addTearDown(harness.dispose);

    await _chooseBackToMainPage(tester);

    expect(find.byKey(const ValueKey('test-main-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('leave-editor-dialog')), findsNothing);
  });

  testWidgets('Back to Main Page protects dirty projects', (tester) async {
    final harness = await _pumpEditor(tester);
    addTearDown(harness.dispose);
    harness.container.read(editorControllerProvider.notifier).addTrack();
    await tester.pump();

    await _chooseBackToMainPage(tester);
    expect(find.byKey(const ValueKey('leave-editor-dialog')), findsOneWidget);
    expect(find.textContaining('Flaudio project file'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsOneWidget);

    await _chooseBackToMainPage(tester);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-main-page')), findsOneWidget);
  });
}

Future<_EditorHarness> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer();
  final router = GoRouter(
    initialLocation: '/editor',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, _) => const Scaffold(
          key: ValueKey('test-main-page'),
          body: Text('Main Page'),
        ),
      ),
      GoRoute(
        path: '/editor',
        name: 'editor',
        builder: (_, _) => const EditorPage(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _EditorHarness(tester, container, router);
}

Future<void> _chooseBackToMainPage(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Back to Main Page'));
  await tester.pumpAndSettle();
}

class _EditorHarness {
  const _EditorHarness(this.tester, this.container, this.router);

  final WidgetTester tester;
  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
