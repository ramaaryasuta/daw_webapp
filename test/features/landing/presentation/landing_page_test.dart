import 'package:daw_webapp/app/router/route_names.dart';
import 'package:daw_webapp/features/landing/presentation/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('landing page presents the product and opens the editor', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('A full DAW.\nRight in your browser.'), findsOneWidget);
    expect(find.text('No ads'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('hero-open-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-destination')), findsOneWidget);
  });

  testWidgets('landing page has no overflow at a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-open-editor')), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    routes: [
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (_, _) => const LandingPage(),
      ),
      GoRoute(
        path: RoutePaths.editor,
        name: RouteNames.editor,
        builder: (_, _) => const Scaffold(key: ValueKey('editor-destination')),
      ),
    ],
  );
}
