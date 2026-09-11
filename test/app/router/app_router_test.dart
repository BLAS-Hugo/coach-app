import 'package:coach_app/app/app.dart';
import 'package:coach_app/app/view/home_shell.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/calendar/presentation/view/day_view_page.dart';
import 'package:coach_app/features/history/presentation/view/history_page.dart';
import 'package:coach_app/features/plans/presentation/view/plans_page.dart';
import 'package:coach_app/features/plans/presentation/view/week_template_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  const plan = Plan(id: 'p1', name: 'Haut / bas', type: PlanType.strength);
  final block = TrainingBlock(
    id: 'b1',
    planId: 'p1',
    name: 'Bloc 1',
    orderIndex: 0,
    startDate: DateOnly.today(),
    durationWeeks: 4,
  );

  late PlanRepository repository;

  // The `Programme` branch builds its bloc from the locator, so routing to
  // it needs a repository even though most of this suite never reads a plan.
  setUp(() {
    repository = _MockPlanRepository();
    when(
      () => repository.watchWeekTemplate(any(), blockId: any(named: 'blockId')),
    ).thenAnswer(
      (_) => Stream.value(
        WeekTemplate(
          plan: plan,
          today: DateOnly.today(),
          blocks: [block],
          block: block,
        ),
      ),
    );
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

    testWidgets('opens the weekly template over the tab bar', (tester) async {
      await tester.pumpWidget(
        App(
          router: createRouter(initialLocation: AppRoutes.weekTemplate('p1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeekTemplatePage), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      verify(() => repository.watchWeekTemplate('p1')).called(1);
    });

    testWidgets("a plan card's Semaine type opens its week", (tester) async {
      when(repository.watchSummaries).thenAnswer(
        (_) => Stream.value([const PlanSummary(plan: plan, blockCount: 1)]),
      );
      await tester.pumpWidget(
        App(router: createRouter(initialLocation: AppRoutes.plans)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Semaine type'));
      await tester.pumpAndSettle();

      expect(find.byType(WeekTemplatePage), findsOneWidget);
      verify(() => repository.watchWeekTemplate('p1')).called(1);
    });

    testWidgets('a duplicated block replaces the week it came from', (
      tester,
    ) async {
      when(
        () => repository.duplicateBlock(
          any(),
          newBlockId: any(named: 'newBlockId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => block.copyWith(id: 'b2'));
      // Tall enough that the block section is built without scrolling.
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        App(
          router: createRouter(initialLocation: AppRoutes.weekTemplate('p1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dupliquer la semaine'));
      await tester.pumpAndSettle();

      expect(find.byType(WeekTemplatePage), findsOneWidget);
      verify(() => repository.watchWeekTemplate('p1', blockId: 'b2')).called(1);
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

  group('AppRoutes.weekTemplate', () {
    test('names the plan, and the block when there is one', () {
      expect(AppRoutes.weekTemplate('p1'), '/plans/p1/week');
      expect(
        AppRoutes.weekTemplate('p1', blockId: 'b2'),
        '/plans/p1/week?block=b2',
      );
    });
  });
}
