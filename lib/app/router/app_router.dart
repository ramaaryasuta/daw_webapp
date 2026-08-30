import 'package:go_router/go_router.dart';

import '../../features/editor/presentation/editor_page.dart';
import '../../features/landing/presentation/landing_page.dart';
import 'route_names.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    GoRoute(
      path: RoutePaths.home,
      name: RouteNames.home,
      builder: (context, state) {
        return const LandingPage();
      },
    ),
    GoRoute(
      path: RoutePaths.editor,
      name: RouteNames.editor,
      builder: (context, state) {
        return const EditorPage();
      },
    ),
  ],
);
