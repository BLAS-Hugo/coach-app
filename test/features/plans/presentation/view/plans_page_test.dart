import 'package:bloc_test/bloc_test.dart';
import 'package:coach_app/app/di/injector.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/features/plans/presentation/bloc/plan_list_bloc.dart';
import 'package:coach_app/features/plans/presentation/view/plans_page.dart';
import 'package:coach_app/features/plans/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/helpers.dart';

class _MockPlanListBloc extends MockBloc<PlanListEvent, PlanListState>
    implements PlanListBloc {}

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  const strength = Plan(id: 'p1', name: 'Haut / bas', type: PlanType.strength);
  const endurance = Plan(id: 'p2', name: 'Semi', type: PlanType.endurance);

  const summaries = [
    PlanSummary(plan: strength, blockCount: 1),
    PlanSummary(plan: endurance, blockCount: 0),
  ];

  late PlanListBloc bloc;

  // The event hierarchy is sealed, so a Fake is out; a real event stands in
  // as the fallback for `any()`.
  setUpAll(() => registerFallbackValue(const PlanListSubscriptionRequested()));

  setUp(() {
    bloc = _MockPlanListBloc();
  });

  Future<void> pumpView(WidgetTester tester, PlanListState state) {
    whenListen(bloc, const Stream<PlanListState>.empty(), initialState: state);
    return tester.pumpApp(
      BlocProvider<PlanListBloc>.value(value: bloc, child: const PlansView()),
    );
  }

  group('PlansView', () {
    testWidgets('titles the screen', (tester) async {
      await pumpView(tester, const PlanListState());

      expect(find.text('Programme'), findsOneWidget);
    });

    for (final status in [PlanListStatus.initial, PlanListStatus.loading]) {
      testWidgets('waits on a spinner while $status', (tester) async {
        await pumpView(tester, PlanListState(status: status));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(NewPlanButton), findsNothing);
      });
    }

    testWidgets('explains a failed read', (tester) async {
      await pumpView(
        tester,
        const PlanListState(status: PlanListStatus.failure),
      );

      expect(find.text('Impossible de charger vos plans.'), findsOneWidget);
      expect(find.byType(PlanCard), findsNothing);
    });

    testWidgets('offers plan creation when there is nothing yet', (
      tester,
    ) async {
      await pumpView(
        tester,
        const PlanListState(status: PlanListStatus.success),
      );

      expect(find.text('Aucun plan'), findsOneWidget);
      expect(
        find.text('Créez un plan pour commencer à programmer vos séances.'),
        findsOneWidget,
      );
      expect(find.byType(NewPlanButton), findsOneWidget);
    });

    testWidgets('renders one card per plan, and the creation button after', (
      tester,
    ) async {
      await pumpView(
        tester,
        const PlanListState(
          status: PlanListStatus.success,
          summaries: summaries,
        ),
      );

      expect(find.byType(PlanCard), findsNWidgets(2));
      expect(find.text('Aucun plan'), findsNothing);
      expect(find.byType(NewPlanButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(NewPlanButton)).dy,
        greaterThan(tester.getTopLeft(find.byType(PlanCard).last).dy),
      );
    });

    testWidgets('creates the plan the sheet came back with', (tester) async {
      await pumpView(
        tester,
        const PlanListState(status: PlanListStatus.success),
      );

      await tester.tap(find.byType(NewPlanButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Haut / bas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const PlanListPlanCreated(
            name: 'Haut / bas',
            type: PlanType.strength,
          ),
        ),
      ).called(1);
    });

    testWidgets('creates nothing when the sheet is dismissed', (tester) async {
      await pumpView(
        tester,
        const PlanListState(status: PlanListStatus.success),
      );

      await tester.tap(find.byType(NewPlanButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });
  });

  group('PlansPage', () {
    late PlanRepository repository;

    setUp(() {
      repository = _MockPlanRepository();
      when(
        repository.watchSummaries,
      ).thenAnswer((_) => Stream.value(const <PlanSummary>[]));
      getIt.registerSingleton<PlanRepository>(repository);
    });

    tearDown(resetDependencies);

    testWidgets('subscribes through the repository in the locator', (
      tester,
    ) async {
      await tester.pumpApp(const PlansPage());
      await tester.pumpAndSettle();

      verify(repository.watchSummaries).called(1);
      expect(find.byType(PlansView), findsOneWidget);
      expect(find.text('Aucun plan'), findsOneWidget);
    });
  });
}
