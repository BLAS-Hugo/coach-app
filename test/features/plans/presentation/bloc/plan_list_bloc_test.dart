import 'package:bloc_test/bloc_test.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/features/plans/presentation/bloc/plan_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

class _FakePlan extends Fake implements Plan {}

void main() {
  late PlanRepository repository;

  const strength = Plan(id: 'p1', name: 'Force', type: PlanType.strength);
  const endurance = Plan(id: 'p2', name: 'Semi', type: PlanType.endurance);

  const summaries = [
    PlanSummary(plan: strength, blockCount: 1),
    PlanSummary(plan: endurance, blockCount: 0),
  ];

  setUpAll(() => registerFallbackValue(_FakePlan()));

  setUp(() {
    repository = _MockPlanRepository();
    when(
      () => repository.watchSummaries(),
    ).thenAnswer((_) => Stream.value(summaries));
    when(() => repository.savePlan(any())).thenAnswer((_) async {});
    when(() => repository.deletePlan(any())).thenAnswer((_) async {});
  });

  PlanListBloc buildBloc() => PlanListBloc(repository);

  group('PlanListBloc', () {
    test('starts on the initial status with no plans', () {
      expect(buildBloc().state, const PlanListState());
    });

    group('PlanListSubscriptionRequested', () {
      blocTest<PlanListBloc, PlanListState>(
        'emits loading then the summaries',
        build: buildBloc,
        act: (bloc) => bloc.add(const PlanListSubscriptionRequested()),
        expect: () => const [
          PlanListState(status: PlanListStatus.loading),
          PlanListState(status: PlanListStatus.success, summaries: summaries),
        ],
      );

      blocTest<PlanListBloc, PlanListState>(
        'emits every later change from the repository',
        build: () {
          when(() => repository.watchSummaries()).thenAnswer(
            (_) => Stream.fromIterable([const <PlanSummary>[], summaries]),
          );
          return buildBloc();
        },
        act: (bloc) => bloc.add(const PlanListSubscriptionRequested()),
        skip: 1,
        expect: () => const [
          PlanListState(status: PlanListStatus.success),
          PlanListState(status: PlanListStatus.success, summaries: summaries),
        ],
      );

      blocTest<PlanListBloc, PlanListState>(
        'emits failure when the stream breaks',
        build: () {
          when(() => repository.watchSummaries()).thenAnswer(
            (_) => Stream<List<PlanSummary>>.error(Exception('no database')),
          );
          return buildBloc();
        },
        act: (bloc) => bloc.add(const PlanListSubscriptionRequested()),
        skip: 1,
        expect: () => const [PlanListState(status: PlanListStatus.failure)],
      );
    });

    group('PlanListPlanCreated', () {
      blocTest<PlanListBloc, PlanListState>(
        'saves a plan under the given name and type',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const PlanListPlanCreated(name: 'Force', type: PlanType.strength),
        ),
        verify: (_) {
          final saved =
              verify(() => repository.savePlan(captureAny())).captured.single
                  as Plan;
          expect(saved.name, 'Force');
          expect(saved.type, PlanType.strength);
          // The repository mints no ids; the caller does.
          expect(saved.id, isNotEmpty);
        },
      );

      blocTest<PlanListBloc, PlanListState>(
        'trims the name it was given',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const PlanListPlanCreated(name: '  Force  ', type: PlanType.strength),
        ),
        verify: (_) {
          final saved =
              verify(() => repository.savePlan(captureAny())).captured.single
                  as Plan;
          expect(saved.name, 'Force');
        },
      );

      blocTest<PlanListBloc, PlanListState>(
        'ignores a blank name instead of saving an unnamed plan',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const PlanListPlanCreated(name: '   ', type: PlanType.strength),
        ),
        expect: () => const <PlanListState>[],
        verify: (_) => verifyNever(() => repository.savePlan(any())),
      );

      blocTest<PlanListBloc, PlanListState>(
        'emits failure when the save is refused',
        build: () {
          when(() => repository.savePlan(any())).thenThrow(Exception('nope'));
          return buildBloc();
        },
        act: (bloc) => bloc.add(
          const PlanListPlanCreated(name: 'Force', type: PlanType.strength),
        ),
        expect: () => const [PlanListState(status: PlanListStatus.failure)],
      );
    });

    group('PlanListPlanDeleted', () {
      blocTest<PlanListBloc, PlanListState>(
        'soft-deletes the plan',
        build: buildBloc,
        act: (bloc) => bloc.add(const PlanListPlanDeleted(planId: 'p1')),
        verify: (_) => verify(() => repository.deletePlan('p1')).called(1),
      );

      blocTest<PlanListBloc, PlanListState>(
        'emits failure when the delete breaks',
        build: () {
          when(() => repository.deletePlan(any())).thenThrow(Exception('nope'));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const PlanListPlanDeleted(planId: 'p1')),
        expect: () => const [PlanListState(status: PlanListStatus.failure)],
      );
    });
  });

  group('PlanListEvent', () {
    test('a subscription request carries no payload', () {
      // Asserted on props rather than on two instances: both would be the
      // same canonical const, so Equatable's identity check would answer
      // before the value comparison this is about ever ran.
      expect(const PlanListSubscriptionRequested().props, isEmpty);
    });

    test('a creation is identified by its name and type', () {
      const created = PlanListPlanCreated(
        name: 'Force',
        type: PlanType.strength,
      );

      expect(
        created,
        const PlanListPlanCreated(name: 'Force', type: PlanType.strength),
      );
      expect(
        created,
        isNot(
          const PlanListPlanCreated(name: 'Force', type: PlanType.endurance),
        ),
      );
    });

    test('a deletion is identified by its plan', () {
      expect(
        const PlanListPlanDeleted(planId: 'p1'),
        const PlanListPlanDeleted(planId: 'p1'),
      );
      expect(
        const PlanListPlanDeleted(planId: 'p1'),
        isNot(const PlanListPlanDeleted(planId: 'p2')),
      );
    });
  });

  group('PlanListState', () {
    test('is empty only once loading has finished', () {
      // While loading there is nothing to show either, but the screen must
      // not offer the "create your first plan" state before it knows.
      expect(const PlanListState().isEmpty, isFalse);
      expect(
        const PlanListState(status: PlanListStatus.loading).isEmpty,
        isFalse,
      );
      expect(
        const PlanListState(status: PlanListStatus.success).isEmpty,
        isTrue,
      );
      expect(
        const PlanListState(
          status: PlanListStatus.success,
          summaries: summaries,
        ).isEmpty,
        isFalse,
      );
    });

    test('copyWith keeps what it is not given', () {
      const state = PlanListState(
        status: PlanListStatus.success,
        summaries: summaries,
      );

      expect(state.copyWith(), state);
      expect(
        state.copyWith(status: PlanListStatus.failure).summaries,
        summaries,
      );
      expect(
        state.copyWith(summaries: const []).status,
        PlanListStatus.success,
      );
    });
  });
}
