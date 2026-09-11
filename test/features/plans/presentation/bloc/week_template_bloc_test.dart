import 'package:bloc_test/bloc_test.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/bloc/week_template_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  late PlanRepository repository;

  const plan = Plan(id: 'p1', name: 'Haut / bas', type: PlanType.strength);

  /// A Monday.
  final today = DateOnly(2026, 9, 7);

  /// Started two weeks ago and runs five, so today is in week 2: it may be
  /// stopped on Sunday the 13th and not made shorter than three weeks.
  final block = TrainingBlock(
    id: 'b1',
    planId: 'p1',
    name: 'Intensification',
    orderIndex: 0,
    startDate: today.addDays(-14),
    durationWeeks: 5,
  );

  const monday = WeeklySlot(
    id: 's1',
    blockId: 'b1',
    weekday: DateTime.monday,
    sessionTemplateId: 't1',
  );
  const thursday = WeeklySlot(
    id: 's4',
    blockId: 'b1',
    weekday: DateTime.thursday,
    sessionTemplateId: 't2',
  );

  const templates = [
    SessionTemplateSummary(
      template: SessionTemplate(id: 't1', planId: 'p1', name: 'Haut'),
    ),
    SessionTemplateSummary(
      template: SessionTemplate(id: 't2', planId: 'p1', name: 'Bas'),
    ),
  ];

  final week = WeekTemplate(
    plan: plan,
    today: today,
    blocks: [block],
    block: block,
    slots: const [monday, thursday],
    templates: templates,
  );

  WeekTemplateState loaded({
    WeekTemplate? of,
    List<WeekTemplateUndo> undo = const [],
    WeekTemplateError? error,
  }) => WeekTemplateState(
    status: WeekTemplateStatus.success,
    week: of ?? week,
    undo: undo,
    error: error,
  );

  const slotsUndo = WeekTemplateSlotsUndo(
    blockId: 'b1',
    slots: [monday, thursday],
  );

  setUpAll(() {
    registerFallbackValue(<WeeklySlot>[]);
    registerFallbackValue(block);
    registerFallbackValue(const SessionTemplate(id: '', planId: '', name: ''));
    registerFallbackValue(today);
  });

  setUp(() {
    repository = _MockPlanRepository();
    when(
      () => repository.watchWeekTemplate(any(), blockId: any(named: 'blockId')),
    ).thenAnswer((_) => Stream.value(week));
    when(
      () => repository.getSlots(any()),
    ).thenAnswer((_) async => const [monday, thursday]);
    when(() => repository.replaceSlots(any(), any())).thenAnswer((_) async {});
    when(() => repository.saveTemplate(any())).thenAnswer((_) async {});
    when(() => repository.saveBlock(any())).thenAnswer((_) async {});
    when(
      () => repository.stopBlock(any(), on: any(named: 'on')),
    ).thenAnswer((_) async {});
  });

  WeekTemplateBloc buildBloc({String? blockId}) =>
      WeekTemplateBloc(repository, planId: 'p1', blockId: blockId);

  /// The week the last `replaceSlots` call committed.
  List<WeeklySlot> committedWeek() =>
      verify(() => repository.replaceSlots('b1', captureAny())).captured.single
          as List<WeeklySlot>;

  group('WeekTemplateBloc', () {
    test('starts on the initial status with nothing to undo', () {
      final bloc = buildBloc();

      expect(bloc.state, const WeekTemplateState());
      expect(bloc.state.canUndo, isFalse);
    });

    group('WeekTemplateSubscriptionRequested', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'emits loading then the week',
        build: buildBloc,
        act: (bloc) => bloc.add(const WeekTemplateSubscriptionRequested()),
        expect: () => [
          const WeekTemplateState(status: WeekTemplateStatus.loading),
          loaded(),
        ],
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'watches the block it was opened on',
        build: () => buildBloc(blockId: 'b9'),
        act: (bloc) => bloc.add(const WeekTemplateSubscriptionRequested()),
        verify: (_) => verify(
          () => repository.watchWeekTemplate('p1', blockId: 'b9'),
        ).called(1),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'emits notFound once the plan is gone',
        build: () {
          when(
            () => repository.watchWeekTemplate(
              any(),
              blockId: any(named: 'blockId'),
            ),
          ).thenAnswer((_) => Stream.value(null));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const WeekTemplateSubscriptionRequested()),
        skip: 1,
        expect: () => const [
          WeekTemplateState(status: WeekTemplateStatus.notFound),
        ],
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'emits failure when the stream breaks',
        build: () {
          when(
            () => repository.watchWeekTemplate(
              any(),
              blockId: any(named: 'blockId'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('no database')));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const WeekTemplateSubscriptionRequested()),
        skip: 1,
        expect: () => const [
          WeekTemplateState(status: WeekTemplateStatus.failure),
        ],
      );
    });

    group('edits before the week has loaded', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'are ignored',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const WeekTemplateDayCleared(weekday: DateTime.monday)),
        expect: () => const <WeekTemplateState>[],
        verify: (_) => verifyNever(() => repository.getSlots(any())),
      );
    });

    group('WeekTemplateSessionAssigned', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'puts a session on a rest day and records how to undo it',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.tuesday,
            templateId: 't2',
          ),
        ),
        expect: () => [
          loaded(undo: const [slotsUndo]),
        ],
        verify: (_) {
          final committed = committedWeek();
          expect(committed, containsAll([monday, thursday]));
          final added = committed.singleWhere(
            (slot) => slot.weekday == DateTime.tuesday,
          );
          expect(added.blockId, 'b1');
          expect(added.sessionTemplateId, 't2');
        },
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'keeps the row when only the session on a day changes',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.monday,
            templateId: 't2',
          ),
        ),
        verify: (_) => expect(committedWeek(), [
          thursday,
          monday.copyWith(sessionTemplateId: 't2'),
        ]),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'writes nothing when the day already holds that session',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.monday,
            templateId: 't1',
          ),
        ),
        expect: () => const <WeekTemplateState>[],
        verify: (_) => verifyNever(() => repository.replaceSlots(any(), any())),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'starts from the week as stored, not as last emitted',
        build: () {
          // The stream still shows Monday alone, but Thursday has already
          // been written: the edit must not erase it.
          when(
            () => repository.getSlots(any()),
          ).thenAnswer((_) async => const [monday, thursday]);
          return buildBloc();
        },
        seed: () => loaded(of: week.copyWith(slots: const [monday])),
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.friday,
            templateId: 't1',
          ),
        ),
        verify: (_) => expect(committedWeek(), containsAll([monday, thursday])),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'leaves a finished block alone',
        build: buildBloc,
        seed: () => loaded(
          of: week.copyWith(block: block.copyWith(startDate: DateOnly(2026))),
        ),
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.tuesday,
            templateId: 't2',
          ),
        ),
        expect: () => const <WeekTemplateState>[],
        verify: (_) => verifyNever(() => repository.getSlots(any())),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'does nothing on a plan with no block',
        build: buildBloc,
        seed: () => loaded(
          of: WeekTemplate(plan: plan, today: today),
        ),
        act: (bloc) => bloc.add(
          const WeekTemplateSessionAssigned(
            weekday: DateTime.tuesday,
            templateId: 't2',
          ),
        ),
        expect: () => const <WeekTemplateState>[],
      );
    });

    group('WeekTemplateSessionCreated', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'creates the template, then puts it on the day',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionCreated(
            weekday: DateTime.saturday,
            name: '  Bas du corps — soulevé  ',
          ),
        ),
        expect: () => [
          loaded(undo: const [slotsUndo]),
        ],
        verify: (_) {
          final template =
              verify(
                    () => repository.saveTemplate(captureAny()),
                  ).captured.single
                  as SessionTemplate;
          expect(template.name, 'Bas du corps — soulevé');
          expect(template.planId, 'p1');
          final added = committedWeek().singleWhere(
            (slot) => slot.weekday == DateTime.saturday,
          );
          expect(added.sessionTemplateId, template.id);
        },
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'ignores a blank name',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionCreated(
            weekday: DateTime.saturday,
            name: '   ',
          ),
        ),
        expect: () => const <WeekTemplateState>[],
        verify: (_) => verifyNever(() => repository.saveTemplate(any())),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'creates nothing on a finished block',
        build: buildBloc,
        seed: () => loaded(
          of: week.copyWith(block: block.copyWith(startDate: DateOnly(2026))),
        ),
        act: (bloc) => bloc.add(
          const WeekTemplateSessionCreated(
            weekday: DateTime.saturday,
            name: 'Bas',
          ),
        ),
        verify: (_) => verifyNever(() => repository.saveTemplate(any())),
      );
    });

    group('WeekTemplateDayCleared', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'makes the day a rest day',
        build: buildBloc,
        seed: loaded,
        act: (bloc) =>
            bloc.add(const WeekTemplateDayCleared(weekday: DateTime.monday)),
        expect: () => [
          loaded(undo: const [slotsUndo]),
        ],
        verify: (_) => expect(committedWeek(), [thursday]),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'writes nothing for a day already at rest',
        build: buildBloc,
        seed: loaded,
        act: (bloc) =>
            bloc.add(const WeekTemplateDayCleared(weekday: DateTime.sunday)),
        expect: () => const <WeekTemplateState>[],
      );
    });

    group('WeekTemplateSessionMoved', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'moves a session onto a rest day',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionMoved(
            from: DateTime.monday,
            to: DateTime.wednesday,
          ),
        ),
        expect: () => [
          loaded(undo: const [slotsUndo]),
        ],
        verify: (_) => expect(committedWeek(), [
          monday.copyWith(weekday: DateTime.wednesday),
          thursday,
        ]),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'swaps two sessions',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(
          const WeekTemplateSessionMoved(
            from: DateTime.monday,
            to: DateTime.thursday,
          ),
        ),
        verify: (_) => expect(committedWeek(), [
          monday.copyWith(weekday: DateTime.thursday),
          thursday.copyWith(weekday: DateTime.monday),
        ]),
      );

      for (final (from, to) in [
        (DateTime.monday, DateTime.monday),
        (DateTime.sunday, DateTime.saturday),
      ]) {
        blocTest<WeekTemplateBloc, WeekTemplateState>(
          'writes nothing moving $from onto $to',
          build: buildBloc,
          seed: loaded,
          act: (bloc) => bloc.add(WeekTemplateSessionMoved(from: from, to: to)),
          expect: () => const <WeekTemplateState>[],
          verify: (_) =>
              verifyNever(() => repository.replaceSlots(any(), any())),
        );
      }
    });

    group('WeekTemplateDurationChanged', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'gives the block its new length and undoes to the old one',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const WeekTemplateDurationChanged(weeks: 6)),
        expect: () => [
          loaded(undo: [WeekTemplateBlockUndo(block: block)]),
        ],
        verify: (_) => verify(
          () => repository.saveBlock(block.copyWith(durationWeeks: 6)),
        ).called(1),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'takes back an early stop',
        build: buildBloc,
        seed: () => loaded(
          of: week.copyWith(
            block: block.copyWith(explicitEndDate: today.addDays(6)),
          ),
        ),
        act: (bloc) => bloc.add(const WeekTemplateDurationChanged(weeks: 5)),
        verify: (_) => verify(() => repository.saveBlock(block)).called(1),
      );

      for (final weeks in [2, 5]) {
        blocTest<WeekTemplateBloc, WeekTemplateState>(
          'writes nothing for $weeks weeks',
          build: buildBloc,
          seed: loaded,
          act: (bloc) => bloc.add(WeekTemplateDurationChanged(weeks: weeks)),
          expect: () => const <WeekTemplateState>[],
          verify: (_) => verifyNever(() => repository.saveBlock(any())),
        );
      }
    });

    group('WeekTemplateBlockStopped', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'ends the block on the last day of this week',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const WeekTemplateBlockStopped()),
        expect: () => [
          loaded(undo: [WeekTemplateBlockUndo(block: block)]),
        ],
        verify: (_) => verify(
          () => repository.stopBlock('b1', on: today.addDays(6)),
        ).called(1),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'does nothing for a block not running',
        build: buildBloc,
        seed: () => loaded(
          of: week.copyWith(block: block.copyWith(startDate: today.addDays(7))),
        ),
        act: (bloc) => bloc.add(const WeekTemplateBlockStopped()),
        expect: () => const <WeekTemplateState>[],
      );
    });

    group('WeekTemplateBlockCreated', () {
      final noBlock = WeekTemplate(plan: plan, today: today);

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'saves the first block, with nothing to undo',
        build: buildBloc,
        seed: () => loaded(of: noBlock),
        act: (bloc) => bloc.add(
          WeekTemplateBlockCreated(
            name: ' Bloc 1 ',
            startDate: today,
            durationWeeks: 4,
          ),
        ),
        expect: () => const <WeekTemplateState>[],
        verify: (_) {
          final saved =
              verify(() => repository.saveBlock(captureAny())).captured.single
                  as TrainingBlock;
          expect(saved.planId, 'p1');
          expect(saved.name, 'Bloc 1');
          expect(saved.startDate, today);
          expect(saved.durationWeeks, 4);
        },
      );

      for (final (name, weeks) in [('  ', 4), ('Bloc 1', 0)]) {
        blocTest<WeekTemplateBloc, WeekTemplateState>(
          'refuses "$name" for $weeks weeks',
          build: buildBloc,
          seed: () => loaded(of: noBlock),
          act: (bloc) => bloc.add(
            WeekTemplateBlockCreated(
              name: name,
              startDate: today,
              durationWeeks: weeks,
            ),
          ),
          verify: (_) => verifyNever(() => repository.saveBlock(any())),
        );
      }
    });

    group('WeekTemplateWeekDuplicated', () {
      final copy = block.copyWith(id: 'b2', startDate: today.addDays(21));

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'starts the next block and points the view at it',
        build: () {
          when(
            () => repository.duplicateBlock(
              any(),
              newBlockId: any(named: 'newBlockId'),
              name: any(named: 'name'),
            ),
          ).thenAnswer((_) async => copy);
          return buildBloc();
        },
        seed: loaded,
        act: (bloc) =>
            bloc.add(const WeekTemplateWeekDuplicated(name: 'Bloc 2')),
        expect: () => [
          WeekTemplateState(
            status: WeekTemplateStatus.success,
            week: week,
            duplicatedBlockId: 'b2',
          ),
        ],
        verify: (_) => verify(
          () => repository.duplicateBlock(
            'b1',
            newBlockId: any(named: 'newBlockId'),
            name: 'Bloc 2',
          ),
        ).called(1),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'does nothing for an ongoing block',
        build: buildBloc,
        seed: () => loaded(
          of: week.copyWith(block: block.copyWith(durationWeeks: null)),
        ),
        act: (bloc) =>
            bloc.add(const WeekTemplateWeekDuplicated(name: 'Bloc 2')),
        expect: () => const <WeekTemplateState>[],
      );
    });

    group('WeekTemplateUndoRequested', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'puts a week back and drops the step',
        build: buildBloc,
        seed: () => loaded(undo: const [slotsUndo]),
        act: (bloc) => bloc.add(const WeekTemplateUndoRequested()),
        expect: () => [loaded()],
        verify: (_) => expect(committedWeek(), [monday, thursday]),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'puts a block back',
        build: buildBloc,
        seed: () => loaded(
          undo: [
            slotsUndo,
            WeekTemplateBlockUndo(block: block),
          ],
        ),
        act: (bloc) => bloc.add(const WeekTemplateUndoRequested()),
        expect: () => [
          loaded(undo: const [slotsUndo]),
        ],
        verify: (_) => verify(() => repository.saveBlock(block)).called(1),
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'does nothing with nothing to undo',
        build: buildBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const WeekTemplateUndoRequested()),
        expect: () => const <WeekTemplateState>[],
      );

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'keeps the step when putting it back fails',
        build: () {
          when(
            () => repository.saveBlock(any()),
          ).thenThrow(const BlockOverlapException('b1', 'b2'));
          return buildBloc();
        },
        seed: () => loaded(undo: [WeekTemplateBlockUndo(block: block)]),
        act: (bloc) => bloc.add(const WeekTemplateUndoRequested()),
        expect: () => [
          loaded(
            undo: [WeekTemplateBlockUndo(block: block)],
            error: WeekTemplateError.blockOverlap,
          ),
        ],
      );
    });

    group('the undo stack', () {
      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'keeps only the most recent steps',
        build: buildBloc,
        seed: () => loaded(
          undo: [
            for (var i = 0; i < WeekTemplateBloc.maxUndo; i++)
              WeekTemplateBlockUndo(block: block.copyWith(orderIndex: i)),
          ],
        ),
        act: (bloc) =>
            bloc.add(const WeekTemplateDayCleared(weekday: DateTime.monday)),
        verify: (bloc) {
          expect(bloc.state.undo, hasLength(WeekTemplateBloc.maxUndo));
          expect(bloc.state.undo.last, slotsUndo);
          expect(
            bloc.state.undo.first,
            WeekTemplateBlockUndo(block: block.copyWith(orderIndex: 1)),
          );
        },
      );
    });

    group('a failed edit', () {
      for (final (thrown, error) in <(Object, WeekTemplateError)>[
        (
          const BlockOverlapException('b1', 'b2'),
          WeekTemplateError.blockOverlap,
        ),
        (
          const PlanTypeConflictException('b1', 'p2'),
          WeekTemplateError.planConflict,
        ),
        (Exception('disk full'), WeekTemplateError.unknown),
      ]) {
        blocTest<WeekTemplateBloc, WeekTemplateState>(
          'reports ${error.name}',
          build: () {
            when(() => repository.saveBlock(any())).thenThrow(thrown);
            return buildBloc();
          },
          seed: loaded,
          act: (bloc) => bloc.add(const WeekTemplateDurationChanged(weeks: 8)),
          expect: () => [loaded(error: error)],
        );
      }

      blocTest<WeekTemplateBloc, WeekTemplateState>(
        'is forgotten by the next edit',
        build: buildBloc,
        seed: () => loaded(error: WeekTemplateError.unknown),
        act: (bloc) =>
            bloc.add(const WeekTemplateDayCleared(weekday: DateTime.monday)),
        expect: () => [
          loaded(),
          loaded(undo: const [slotsUndo]),
        ],
      );
    });
  });
}
