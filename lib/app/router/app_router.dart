import 'package:coach_app/app/view/home_shell.dart';
import 'package:coach_app/features/calendar/presentation/view/day_view_page.dart';
import 'package:coach_app/features/history/presentation/view/history_page.dart';
import 'package:coach_app/features/plans/presentation/view/plans_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route paths, so no string literal is written twice.
abstract final class AppRoutes {
  static const String today = '/';
  static const String plans = '/plans';
  static const String history = '/history';
}

/// The app router.
///
/// A [StatefulShellRoute] gives each tab its own [Navigator], so pushing a
/// session detail inside `Programme` and switching to `Historique` and back
/// returns to that detail rather than resetting the tab.
GoRouter createRouter({String initialLocation = AppRoutes.today}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const DayViewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.plans,
                builder: (context, state) => const PlansPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _RouteNotFoundPage(),
  );
}

/// Reached only through a malformed deep link — the app has no external
/// entry points, so this is a developer-facing dead end, not a user-facing
/// screen, and deliberately carries no localised copy.
class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('404')));
  }
}
