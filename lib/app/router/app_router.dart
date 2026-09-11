import 'package:coach_app/app/view/home_shell.dart';
import 'package:coach_app/features/calendar/presentation/view/day_view_page.dart';
import 'package:coach_app/features/history/presentation/view/history_page.dart';
import 'package:coach_app/features/plans/presentation/view/plans_page.dart';
import 'package:coach_app/features/plans/presentation/view/week_template_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route paths, so no string literal is written twice.
abstract final class AppRoutes {
  static const String today = '/';
  static const String plans = '/plans';
  static const String history = '/history';

  /// The weekly template of [planId]'s block [blockId], or of the block the
  /// plan is on now when none is named.
  static String weekTemplate(String planId, {String? blockId}) => Uri(
    path: '$plans/$planId/week',
    queryParameters: blockId == null ? null : {'block': blockId},
  ).toString();
}

/// The app router.
///
/// A [StatefulShellRoute] gives each tab its own [Navigator], so pushing a
/// session detail inside `Programme` and switching to `Historique` and back
/// returns to that detail rather than resetting the tab.
GoRouter createRouter({String initialLocation = AppRoutes.today}) {
  // The navigator above the shell. Editors are pushed on it so they cover
  // the tab bar: design screen 4b has an action bar where the tabs would be.
  // One per router, so two routers never share a GlobalKey.
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
                routes: [
                  GoRoute(
                    path: ':planId/week',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final planId = state.pathParameters['planId']!;
                      return WeekTemplatePage(
                        // Keyed on the block so replacing one block's week
                        // with another's builds a fresh bloc.
                        key: ValueKey(state.uri.toString()),
                        planId: planId,
                        blockId: state.uri.queryParameters['block'],
                        onOpenBlock: (blockId) => context.pushReplacement(
                          AppRoutes.weekTemplate(planId, blockId: blockId),
                        ),
                      );
                    },
                  ),
                ],
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
