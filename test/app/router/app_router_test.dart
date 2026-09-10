import 'package:coach_app/app/app.dart';
import 'package:coach_app/app/view/home_shell.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/features/calendar/presentation/view/day_view_page.dart';
import 'package:coach_app/features/history/presentation/view/history_page.dart';
import 'package:coach_app/features/plans/presentation/view/plans_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  // The `Programme` branch builds its bloc from the locator, so routing to
  // it needs a repository even though this suite never reads a plan.
  setUp(() {
    final repository = _MockPlanRepository();
    // A stream that never emits would leave the spinner running and
    // pumpAndSettle would time out.
    when(
      repository.watchSummaries,
    ).thenAnswer((_) => Stream.value(const <PlanSummary>[]));
    getIt.registerSingleton<PlanRepository>(repository);
  });

  tearDown(resetDependencies);

  group('createRouter', () {
    testWidgets('starts on the day view inside the shell', (tester) async {
      await tester.pumpWidget(App(router: createRouter()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(DayViewPage), findsOneWidget);
    });

    for (final (location, page) in <(String, Type)>[
      (AppRoutes.today, DayViewPage),
      (AppRoutes.plans, PlansPage),
      (AppRoutes.history, HistoryPage),
    ]) {
      testWidgets('renders $page for $location', (tester) async {
        await tester.pumpWidget(
          App(router: createRouter(initialLocation: location)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(page), findsOneWidget);
      });
    }

    testWidgets('tapping a tab switches branch and keeps the shell', (
      tester,
    ) async {
      await tester.pumpWidget(App(router: createRouter()));
      await tester.pumpAndSettle();

      // The active tab renders uppercase, an inactive one does not.
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryPage), findsOneWidget);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('an unknown route falls back to the error page', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(router: createRouter(initialLocation: '/nope')),
      );
      await tester.pumpAndSettle();

      expect(find.text('404'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
    });
  });
}
