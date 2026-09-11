import 'package:bloc_test/bloc_test.dart';
import 'package:coach_app/app/di/injector.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/bloc/week_template_bloc.dart';
import 'package:coach_app/features/plans/presentation/view/week_template_page.dart';
import 'package:coach_app/features/plans/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/helpers.dart';

class _MockWeekTemplateBloc
    extends MockBloc<WeekTemplateEvent, WeekTemplateState>
    implements WeekTemplateBloc {}

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  const plan = Plan(id: 'p1', name: 'Haut / bas', type: PlanType.strength);

  /// A Monday.
  final today = DateOnly(2026, 9, 7);

  /// Two weeks in, five long: running, stoppable, duplicable.
  final block = TrainingBlock(
    id: 'b1',
    planId: 'p1',
    name: 'Intensification',
    orderIndex: 0,
    startDate: today.addDays(-14),
    durationWeeks: 5,
  );

  const templates = [
    SessionTemplateSummary(
      template: SessionTemplate(
        id: 't1',
        planId: 'p1',
        name: 'Haut du corps — poussée',
      ),
      exerciseCount: 6,
      setCount: 24,
    ),
    SessionTemplateSummary(
      template: SessionTemplate(
        id: 't2',
        planId: 'p1',
        name: 'Bas du corps — squat',
      ),
      exerciseCount: 5,
      setCount: 21,
    ),
  ];

  final week = WeekTemplate(
    plan: plan,
    today: today,
    blocks: [block],
    block: block,
    slots: const [
      WeeklySlot(
        id: 's1',
        blockId: 'b1',
        weekday: DateTime.monday,
        sessionTemplateId: 't1',
      ),
      WeeklySlot(
        id: 's3',
        blockId: 'b1',
        weekday: DateTime.wednesday,
        sessionTemplateId: 't2',
      ),
    ],
    templates: templates,
  );

  WeekTemplateState loaded(WeekTemplate of, {bool canUndo = false}) =>
      WeekTemplateState(
        status: WeekTemplateStatus.success,
        week: of,
        undo: [if (canUndo) WeekTemplateBlockUndo(block: block)],
      );

  late WeekTemplateBloc bloc;
  late List<String> openedBlocks;

  setUpAll(() => registerFallbackValue(const WeekTemplateUndoRequested()));

  setUp(() {
    bloc = _MockWeekTemplateBloc();
    openedBlocks = [];
  });

  Future<void> pumpView(
    WidgetTester tester,
    WeekTemplateState state, {
    Stream<WeekTemplateState>? states,
  }) async {
    // Tall enough for the seven days, the block section and the action bar
    // at once, so no test depends on scrolling.
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      bloc,
      states ?? const Stream<WeekTemplateState>.empty(),
      initialState: state,
    );
    await tester.pumpApp(
      BlocProvider<WeekTemplateBloc>.value(
        value: bloc,
        child: WeekTemplateView(onOpenBlock: openedBlocks.add),
      ),
    );
  }

  group('WeekTemplateView', () {
    for (final status in [
      WeekTemplateStatus.initial,
      WeekTemplateStatus.loading,
    ]) {
      testWidgets('waits on a spinner while $status', (tester) async {
        await pumpView(tester, WeekTemplateState(status: status));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }

    testWidgets('says so when the week cannot load', (tester) async {
      await pumpView(
        tester,
        const WeekTemplateState(status: WeekTemplateStatus.failure),
      );

      expect(find.text('Impossible de charger la semaine type.'), findsOne);
    });

    testWidgets('says so when the plan is gone', (tester) async {
      await pumpView(
        tester,
        const WeekTemplateState(status: WeekTemplateStatus.notFound),
      );

      expect(find.text("Ce plan n'existe plus."), findsOneWidget);
    });

    group('with a running block', () {
      testWidgets('heads the screen with the plan type and block', (
        tester,
      ) async {
        await pumpView(tester, loaded(week));

        expect(find.text('FORCE · BLOC 1'), findsOneWidget);
        expect(find.text('Semaine type'), findsOneWidget);
        expect(
          find.text(
            '2 séances · répétée 5 semaines · '
            "modifs appliquées à partir d'aujourd'hui",
          ),
          findsOneWidget,
        );
      });

      testWidgets('lists all seven days', (tester) async {
        await pumpView(tester, loaded(week));

        expect(find.byType(WeekDayRow), findsNWidgets(7));
        expect(find.text('Haut du corps — poussée'), findsOneWidget);
        expect(find.text('6 exercices · 24 séries'), findsOneWidget);
        expect(find.text('Bas du corps — squat'), findsOneWidget);
        expect(find.text('repos'), findsNWidgets(5));
      });

      testWidgets('shows the block length and the stop action', (tester) async {
        await pumpView(tester, loaded(week));

        expect(find.text('BLOC'), findsOneWidget);
        expect(find.text('5 semaines'), findsOneWidget);
        expect(find.text('puis ajuster'), findsOneWidget);
        expect(find.text('Arrêter le bloc après cette semaine'), findsOne);
      });

      testWidgets('Annuler is inert with nothing to undo', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Annuler'));

        verifyNever(() => bloc.add(any()));
      });

      testWidgets('Annuler takes back the last edit', (tester) async {
        await pumpView(tester, loaded(week, canUndo: true));

        await tester.tap(find.text('Annuler'));

        verify(() => bloc.add(const WeekTemplateUndoRequested())).called(1);
      });

      testWidgets('a rest day takes one of the plan sessions', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('repos').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bas du corps — squat').last);
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const WeekTemplateSessionAssigned(
              weekday: DateTime.tuesday,
              templateId: 't2',
            ),
          ),
        ).called(1);
      });

      testWidgets('a rest day takes a new session', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('repos').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Gainage');
        await tester.pump();
        await tester.tap(find.text('Créer'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const WeekTemplateSessionCreated(
              weekday: DateTime.sunday,
              name: 'Gainage',
            ),
          ),
        ).called(1);
      });

      testWidgets('a session day can be put to rest', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Haut du corps — poussée'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mettre en repos'));
        await tester.pumpAndSettle();

        verify(
          () =>
              bloc.add(const WeekTemplateDayCleared(weekday: DateTime.monday)),
        ).called(1);
      });

      testWidgets('a dismissed day sheet changes nothing', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('repos').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler').last);
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
      });

      testWidgets('dragging a session moves it', (tester) async {
        await pumpView(tester, loaded(week));

        final handle = find.byKey(WeekDayRow.handleKey(DateTime.monday));
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('repos').first));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const WeekTemplateSessionMoved(
              from: DateTime.monday,
              to: DateTime.tuesday,
            ),
          ),
        ).called(1);
      });

      testWidgets('the length changes through its sheet', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Durée du bloc'));
        await tester.pumpAndSettle();
        // The sheet's stepper, above the rest days' own "+".
        await tester.tap(find.text('+').last);
        await tester.pump();
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(const WeekTemplateDurationChanged(weeks: 6)),
        ).called(1);
      });

      testWidgets('a dismissed length sheet changes nothing', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Durée du bloc'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler').last);
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
      });

      testWidgets('duplicating names the next block', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Dupliquer la semaine'));

        verify(
          () => bloc.add(const WeekTemplateWeekDuplicated(name: 'Bloc 2')),
        ).called(1);
      });

      testWidgets('stopping ends the block after this week', (tester) async {
        await pumpView(tester, loaded(week));

        await tester.tap(find.text('Arrêter le bloc après cette semaine'));

        verify(() => bloc.add(const WeekTemplateBlockStopped())).called(1);
      });

      testWidgets('the back chevron leaves the screen', (tester) async {
        whenListen(
          bloc,
          const Stream<WeekTemplateState>.empty(),
          initialState: loaded(week),
        );
        await tester.pumpApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<WeekTemplateBloc>.value(
                    value: bloc,
                    child: WeekTemplateView(onOpenBlock: openedBlocks.add),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Retour'));
        await tester.pumpAndSettle();

        expect(find.byType(WeekTemplateView), findsNothing);
      });
    });

    group('with a finished block', () {
      final finished = week.copyWith(
        block: block.copyWith(startDate: today.addDays(-70)),
      );

      testWidgets('reads only', (tester) async {
        await pumpView(tester, loaded(finished));

        expect(
          find.text(
            '2 séances · répétée 5 semaines · bloc terminé, lecture seule',
          ),
          findsOneWidget,
        );
        expect(find.text('Arrêter le bloc après cette semaine'), findsNothing);
        expect(find.text('+'), findsNothing);

        await tester.tap(find.text('Durée du bloc'));
        await tester.tap(find.text('repos').first);
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
      });

      testWidgets('can still seed the next block', (tester) async {
        await pumpView(tester, loaded(finished));

        await tester.tap(find.text('Dupliquer la semaine'));

        verify(
          () => bloc.add(const WeekTemplateWeekDuplicated(name: 'Bloc 2')),
        ).called(1);
      });
    });

    testWidgets('an ongoing block repeats without end', (tester) async {
      await pumpView(
        tester,
        loaded(week.copyWith(block: block.copyWith(durationWeeks: null))),
      );

      expect(find.textContaining('répétée sans fin'), findsOneWidget);
      expect(find.text('sans fin'), findsOneWidget);

      await tester.tap(find.text('Dupliquer la semaine'));

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('an endurance plan heads with its own type', (tester) async {
      await pumpView(
        tester,
        loaded(week.copyWith(plan: plan.copyWith(type: PlanType.endurance))),
      );

      expect(find.text('ENDURANCE · BLOC 1'), findsOneWidget);
    });

    testWidgets('a block missing from the list heads with the type alone', (
      tester,
    ) async {
      await pumpView(tester, loaded(week.copyWith(blocks: const [])));

      expect(find.text('FORCE'), findsOneWidget);
    });

    group('with no block yet', () {
      final empty = WeekTemplate(plan: plan, today: today);

      testWidgets('explains blocks and offers the first', (tester) async {
        await pumpView(tester, loaded(empty));

        expect(find.text('Aucun bloc'), findsOneWidget);
        expect(find.byType(WeekDayRow), findsNothing);
        expect(find.text('Arrêter le bloc après cette semaine'), findsNothing);
      });

      testWidgets('creates it through its sheet', (tester) async {
        await pumpView(tester, loaded(empty));

        await tester.tap(find.text('Créer le premier bloc'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Créer'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            WeekTemplateBlockCreated(
              name: 'Bloc 1',
              startDate: today,
              durationWeeks: 4,
            ),
          ),
        ).called(1);
      });

      testWidgets('a dismissed sheet creates nothing', (tester) async {
        await pumpView(tester, loaded(empty));

        await tester.tap(find.text('Créer le premier bloc'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler').last);
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
      });
    });

    for (final (error, message) in [
      (
        WeekTemplateError.blockOverlap,
        'Ces dates chevauchent un autre bloc de ce plan.',
      ),
      (
        WeekTemplateError.planConflict,
        'Ces dates chevauchent un autre plan du même type. '
            "Arrêtez d'abord son bloc en cours.",
      ),
      (
        WeekTemplateError.unknown,
        "La modification n'a pas pu être enregistrée.",
      ),
    ]) {
      testWidgets('reports ${error.name} in a snackbar', (tester) async {
        final state = loaded(week);
        await pumpView(
          tester,
          state,
          states: Stream.value(
            WeekTemplateState(
              status: state.status,
              week: state.week,
              error: error,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('opens the block a duplicate made', (tester) async {
      final state = loaded(week);
      await pumpView(
        tester,
        state,
        states: Stream.value(state.copyWith(duplicatedBlockId: 'b2')),
      );
      await tester.pump();

      expect(openedBlocks, ['b2']);
    });
  });

  group('WeekTemplatePage', () {
    tearDown(resetDependencies);

    testWidgets('watches the plan and block it was opened on', (tester) async {
      final repository = _MockPlanRepository();
      when(
        () =>
            repository.watchWeekTemplate(any(), blockId: any(named: 'blockId')),
      ).thenAnswer((_) => Stream.value(week));
      getIt.registerSingleton<PlanRepository>(repository);

      await tester.pumpApp(
        WeekTemplatePage(planId: 'p1', blockId: 'b1', onOpenBlock: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Semaine type'), findsOneWidget);
      verify(() => repository.watchWeekTemplate('p1', blockId: 'b1')).called(1);
    });
  });
}
