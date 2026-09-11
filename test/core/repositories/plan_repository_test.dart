import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/plan_repository.dart';
import 'package:coach_app/core/repositories/schedule_repository.dart';
import 'package:coach_app/core/repositories/session_content_repository.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repository;
  late SessionContentRepository content;
  late ScheduleRepository schedule;

  /// The day every test treats as "today", so "has this block started?"
  /// never depends on the wall clock.
  final today = DateOnly(2026, 9, 7);

  const strength = Plan(id: 'p1', name: 'Upper/Lower', type: PlanType.strength);
  const endurance = Plan(
    id: 'p2',
    name: 'Semi-marathon',
    type: PlanType.endurance,
  );

  TrainingBlock block(
    String id, {
    required DateOnly startDate,
    String planId = 'p1',
    int? durationWeeks = 4,
    DateOnly? explicitEndDate,
    int orderIndex = 0,
  }) => TrainingBlock(
    id: id,
    planId: planId,
    name: 'Accumulation',
    orderIndex: orderIndex,
    startDate: startDate,
    durationWeeks: durationWeeks,
    explicitEndDate: explicitEndDate,
  );

  setUp(() async {
    db = openTestDatabase();
    final clock = clockAt(DateTime(2026, 9, 7, 10));
    repository = DriftPlanRepository(
      PlanningDao(db, now: clock),
      ContentDao(db, now: clock),
      SchedulingDao(db, now: clock),
    );
    content = DriftSessionContentRepository(ContentDao(db, now: clock));
    schedule = DriftScheduleRepository(SchedulingDao(db, now: clock));
    await repository.savePlan(strength);
    await repository.savePlan(endurance);
  });

  tearDown(() => db.close());

  group('plans', () {
    test('reads back a saved plan as a domain model', () async {
      expect(await repository.findPlan('p1'), strength);
    });

    test('updates a plan in place', () async {
      await repository.savePlan(
        strength.copyWith(name: 'Push/Pull', notes: 'Cycle 2'),
      );

      final plans = await repository.watchPlans().first;
      expect(plans.map((p) => p.name), ['Push/Pull', 'Semi-marathon']);
      expect(plans.first.notes, 'Cycle 2');
    });

    test('watchPlans orders by name and excludes deleted plans', () async {
      await repository.deletePlan('p1');

      expect(await repository.watchPlans().first, [endurance]);
      expect(await repository.findPlan('p1'), isNull);
    });

    test(
      'deleting a plan cascades to its blocks, templates and slots',
      () async {
        await repository.saveTemplate(
          const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
        );
        await repository.saveBlock(block('b1', startDate: today));
        await repository.setSlot(
          const WeeklySlot(
            id: 's1',
            blockId: 'b1',
            weekday: DateTime.monday,
            sessionTemplateId: 't1',
          ),
        );

        await repository.deletePlan('p1');

        expect(await repository.watchBlocks('p1').first, isEmpty);
        expect(await repository.watchTemplates('p1').first, isEmpty);
        expect(await repository.watchSlots('b1').first, isEmpty);
        // Nothing was actually removed: a log points at this plan and must
        // stay readable in history (PRD §4.1).
        expect(await db.select(db.trainingBlocks).get(), hasLength(1));
        expect(await db.select(db.weeklySlots).get(), hasLength(1));
      },
    );
  });

  group('blocks', () {
    test('orders blocks chronologically', () async {
      await repository.saveBlock(
        block('b2', startDate: DateOnly(2026, 10, 5), orderIndex: 100),
      );
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      final blocks = await repository.watchBlocks('p1').first;
      expect(blocks.map((b) => b.id), ['b1', 'b2']);
    });

    test('reads back the derived end date', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      final saved = (await repository.watchBlocks('p1').first).single;
      expect(saved.endDate, DateOnly(2026, 10, 4));
      expect(saved.explicitEndDate, isNull);
    });

    test('rejects a block overlapping a sibling', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      await expectLater(
        repository.saveBlock(block('b2', startDate: DateOnly(2026, 9, 28))),
        throwsA(isA<BlockOverlapException>()),
      );
    });

    test('accepts a block starting the day after a sibling ends', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      await expectLater(
        repository.saveBlock(block('b2', startDate: DateOnly(2026, 10, 5))),
        completes,
      );
    });

    test('does not treat a block as overlapping itself', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      await expectLater(
        repository.saveBlock(
          block('b1', startDate: DateOnly(2026, 9, 7), durationWeeks: 6),
        ),
        completes,
      );
    });

    test('ignores a deleted sibling when checking overlap', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 14)));
      await repository.deleteBlock('b1');

      await expectLater(
        repository.saveBlock(block('b2', startDate: DateOnly(2026, 9, 14))),
        completes,
      );
    });

    test('an ongoing block overlaps everything after its start', () async {
      await repository.saveBlock(
        block('b1', startDate: DateOnly(2026, 9, 7), durationWeeks: null),
      );

      await expectLater(
        repository.saveBlock(block('b2', startDate: DateOnly(2027, 2, 15))),
        throwsA(isA<BlockOverlapException>()),
      );
    });

    test('rejects a block overlapping another plan of the same type', () async {
      await repository.savePlan(
        const Plan(id: 'p3', name: 'Force', type: PlanType.strength),
      );
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      // Two active strength plans would put two strength cards on the same
      // day, and PRD §5.1 allows at most one per type.
      await expectLater(
        repository.saveBlock(
          block('b2', planId: 'p3', startDate: DateOnly(2026, 9, 14)),
        ),
        throwsA(isA<PlanTypeConflictException>()),
      );
    });

    test('allows a plan of the other type to run concurrently', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 7)));

      await expectLater(
        repository.saveBlock(
          block('b2', planId: 'p2', startDate: DateOnly(2026, 9, 7)),
        ),
        completes,
      );
    });

    test('deletes a block that has not started yet', () async {
      await repository.saveBlock(block('b1', startDate: DateOnly(2026, 9, 8)));

      await repository.deleteBlock('b1');

      expect(await repository.watchBlocks('p1').first, isEmpty);
    });

    test('refuses to delete a block that has started', () async {
      await repository.saveBlock(block('b1', startDate: today));

      // Deleting a started block would orphan the sessions already logged
      // against it; stopping it is the sanctioned move (PRD §4.1).
      await expectLater(
        repository.deleteBlock('b1'),
        throwsA(isA<BlockStartedException>()),
      );
      expect(await repository.watchBlocks('p1').first, hasLength(1));
    });

    test('stopping a block sets an explicit end date', () async {
      await repository.saveBlock(block('b1', startDate: today));

      await repository.stopBlock('b1', on: DateOnly(2026, 9, 13));

      final stopped = (await repository.watchBlocks('p1').first).single;
      expect(stopped.explicitEndDate, DateOnly(2026, 9, 13));
      expect(stopped.endDate, DateOnly(2026, 9, 13));
    });

    test('stopping frees the dates a later block can use', () async {
      await repository.saveBlock(block('b1', startDate: today));
      await repository.stopBlock('b1', on: DateOnly(2026, 9, 13));

      await expectLater(
        repository.saveBlock(block('b2', startDate: DateOnly(2026, 9, 14))),
        completes,
      );
    });
  });

  group('session templates', () {
    setUp(() async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
      );
    });

    test('reads templates back for their plan only', () async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't2', planId: 'p2', name: 'Sortie longue'),
      );

      expect((await repository.watchTemplates('p1').first).map((t) => t.id), [
        't1',
      ]);
    });

    test('orders templates by name, accents folded', () async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't2', planId: 'p1', name: 'Étirements'),
      );
      await repository.saveTemplate(
        const SessionTemplate(id: 't3', planId: 'p1', name: 'Bas du corps'),
      );

      expect(
        (await repository.watchTemplates('p1').first).map((t) => t.id),
        // Bas, Étirements, Haut: folded, "Étirements" files under E where a
        // reader looks for it, not after "Haut" where its code unit sits.
        ['t3', 't2', 't1'],
      );
    });

    test('deleting a template clears the weekly slots using it', () async {
      await repository.saveBlock(block('b1', startDate: today));
      await repository.setSlot(
        const WeeklySlot(
          id: 's1',
          blockId: 'b1',
          weekday: DateTime.monday,
          sessionTemplateId: 't1',
        ),
      );

      await repository.deleteTemplate('t1');

      // A slot pointing at a deleted template would schedule a session with
      // no content.
      expect(await repository.watchSlots('b1').first, isEmpty);
    });
  });

  group('weekly slots', () {
    setUp(() async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
      );
      await repository.saveTemplate(
        const SessionTemplate(id: 't2', planId: 'p1', name: 'Bas du corps'),
      );
      await repository.saveBlock(block('b1', startDate: today));
    });

    WeeklySlot slot(String id, int weekday, String templateId) => WeeklySlot(
      id: id,
      blockId: 'b1',
      weekday: weekday,
      sessionTemplateId: templateId,
    );

    test('orders slots by weekday', () async {
      await repository.setSlot(slot('s1', DateTime.friday, 't1'));
      await repository.setSlot(slot('s2', DateTime.tuesday, 't2'));

      expect((await repository.watchSlots('b1').first).map((s) => s.id), [
        's2',
        's1',
      ]);
    });

    test('replaces the slot already on that weekday', () async {
      await repository.setSlot(slot('s1', DateTime.monday, 't1'));

      await repository.setSlot(slot('s2', DateTime.monday, 't2'));

      final slots = await repository.watchSlots('b1').first;
      expect(slots.single.sessionTemplateId, 't2');
      // The partial unique index only tolerates this because the old row is
      // soft-deleted rather than left live.
      expect(await db.select(db.weeklySlots).get(), hasLength(2));
    });

    test('updates a slot in place when the id is unchanged', () async {
      await repository.setSlot(slot('s1', DateTime.monday, 't1'));

      await repository.setSlot(slot('s1', DateTime.monday, 't2'));

      expect(await db.select(db.weeklySlots).get(), hasLength(1));
      final slots = await repository.watchSlots('b1').first;
      expect(slots.single.sessionTemplateId, 't2');
    });

    test('clears the slot on a weekday', () async {
      await repository.setSlot(slot('s1', DateTime.monday, 't1'));

      await repository.clearSlot(blockId: 'b1', weekday: DateTime.monday);

      expect(await repository.watchSlots('b1').first, isEmpty);
    });
  });

  group('cascading deletes', () {
    setUp(() async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
      );
      await repository.saveBlock(block('b1', startDate: today));
      await repository.setSlot(
        const WeeklySlot(
          id: 's1',
          blockId: 'b1',
          weekday: DateTime.monday,
          sessionTemplateId: 't1',
        ),
      );
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: 'x1',
              createdAt: DateTime(2026, 9, 7),
              updatedAt: DateTime(2026, 9, 7),
              name: 'Squat',
            ),
          );
      await content.replaceStrengthContent(
        templateId: 't1',
        entries: [
          const ExerciseEntry(
            id: 'e1',
            sessionTemplateId: 't1',
            exerciseId: 'x1',
            orderIndex: 0,
          ),
        ],
        setsByEntry: {
          'e1': [
            const PlannedSet(
              id: 'ps1',
              exerciseEntryId: 'e1',
              orderIndex: 0,
              kind: SetKind.weightReps,
              weight: 80,
              reps: 5,
            ),
          ],
        },
      );
      await schedule.setOverride(
        const WeekOverride(
          id: 'o1',
          blockId: 'b1',
          weekIndex: 1,
          weekday: DateTime.monday,
          action: WeekOverrideAction.remove,
        ),
      );
      await db
          .into(db.occurrenceMoves)
          .insert(
            OccurrenceMovesCompanion.insert(
              id: 'm1',
              createdAt: DateTime(2026, 9, 7),
              updatedAt: DateTime(2026, 9, 7),
              blockId: 'b1',
              date: DateOnly(2026, 9, 14),
              targetDate: DateOnly(2026, 9, 15),
            ),
          );
    });

    test('deleting a plan retires its templates content', () async {
      await repository.deletePlan('p1');

      // Content left live under a deleted plan would come back the moment
      // anything read a template by id, and would count against nothing.
      expect(await content.watchEntries('t1').first, isEmpty);
      expect(await content.watchPlannedSets('e1').first, isEmpty);
    });

    test('deleting a plan retires its blocks deviations', () async {
      await repository.deletePlan('p1');

      expect(await schedule.watchOverrides('b1').first, isEmpty);
      expect(await schedule.watchMoves('b1').first, isEmpty);
    });

    test('deleting a template retires its content', () async {
      await repository.deleteTemplate('t1');

      expect(await content.watchEntries('t1').first, isEmpty);
      expect(await content.watchPlannedSets('e1').first, isEmpty);
    });

    test('deleting a block retires its deviations', () async {
      await repository.stopBlock('b1', on: today);
      await repository.saveBlock(
        block('b2', startDate: DateOnly(2026, 9, 21), orderIndex: 100),
      );
      await db
          .into(db.weekOverrides)
          .insert(
            WeekOverridesCompanion.insert(
              id: 'o2',
              createdAt: DateTime(2026, 9, 7),
              updatedAt: DateTime(2026, 9, 7),
              blockId: 'b2',
              weekIndex: 0,
              weekday: DateTime.monday,
              action: WeekOverrideAction.remove,
            ),
          );

      await repository.deleteBlock('b2');

      expect(await schedule.watchOverrides('b2').first, isEmpty);
      // The other block keeps its own.
      expect(await schedule.watchOverrides('b1').first, hasLength(1));
    });

    test('endurance content goes with its plan', () async {
      await content.replaceEnduranceContent(
        templateId: 't1',
        repeatGroups: [
          const RepeatGroup(
            id: 'g1',
            sessionTemplateId: 't1',
            orderIndex: 0,
            repeatCount: 6,
          ),
        ],
        blocks: [
          const EnduranceBlock(
            id: 'eb1',
            sessionTemplateId: 't1',
            orderIndex: 0,
            role: EnduranceBlockRole.work,
            measure: EnduranceMeasure.distance,
            targetValue: 400,
            repeatGroupId: 'g1',
          ),
        ],
      );

      await repository.deletePlan('p1');

      expect(await content.watchEnduranceBlocks('t1').first, isEmpty);
      expect(await content.watchRepeatGroups('t1').first, isEmpty);
    });
  });

  group('exception messages', () {
    test('name the block in the way and the one it collides with', () {
      // These reach the user through a snackbar in M2, so they have to say
      // which block is the problem, not just that there is one.
      expect(
        const BlockOverlapException('b2', 'b1').toString(),
        contains('b2'),
      );
      expect(
        const BlockOverlapException('b2', 'b1').toString(),
        contains('b1'),
      );
      expect(
        const PlanTypeConflictException('b2', 'p1').toString(),
        contains('p1'),
      );
      expect(const BlockStartedException('b1').toString(), contains('stopped'));
    });
  });

  group('plan summaries', () {
    setUp(() async {
      await repository.saveTemplate(
        const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
      );
      await repository.saveTemplate(
        const SessionTemplate(id: 't2', planId: 'p1', name: 'Bas du corps'),
      );
    });

    /// The card for [planId]. Summaries come back ordered by plan name, so
    /// indexing into the list would silently pick the wrong plan.
    Future<PlanSummary> summaryOf(String planId) async =>
        (await repository.watchSummaries().first).firstWhere(
          (summary) => summary.plan.id == planId,
        );

    Future<void> addSlots(String blockId, List<int> weekdays) async {
      for (final weekday in weekdays) {
        await repository.setSlot(
          WeeklySlot(
            id: 'sl-$blockId-$weekday',
            blockId: blockId,
            weekday: weekday,
            sessionTemplateId: 't1',
          ),
        );
      }
    }

    test(
      'reads the week the active block is in, 1-based for display',
      () async {
        // Block starts three weeks before today, so today sits in week 2
        // counting from zero — "semaine 3 / 5" on design screen 4a.
        await repository.saveBlock(
          block(
            'b1',
            startDate: today.addDays(-14),
            durationWeeks: 5,
          ).copyWith(name: 'Intensification'),
        );

        final summary = await summaryOf('p1');

        expect(summary.currentBlock?.name, 'Intensification');
        expect(summary.weekIndex, 2);
        expect(summary.weekCount, 5);
        expect(summary.isActive, isTrue);
      },
    );

    test('numbers the current block among its siblings', () async {
      await repository.saveBlock(block('b1', startDate: today.addDays(-70)));
      await repository.saveBlock(
        block('b2', startDate: today.addDays(-7), durationWeeks: 5),
      );

      final summary = await summaryOf('p1');

      // "bloc 2" — 1-based, and counted in chronological order.
      expect(summary.currentBlockOrdinal, 2);
      expect(summary.blockCount, 2);
    });

    test('counts the sessions the active block schedules each week', () async {
      await repository.saveBlock(block('b1', startDate: today));
      await addSlots('b1', [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
        DateTime.saturday,
      ]);

      final summary = await summaryOf('p1');

      expect(summary.sessionsPerWeek, 4);
    });

    test('a plan whose blocks are all over is not active', () async {
      await repository.saveBlock(block('b1', startDate: today.addDays(-70)));

      final summary = await summaryOf('p1');

      expect(summary.isActive, isFalse);
      expect(summary.currentBlock, isNull);
      expect(summary.weekIndex, isNull);
      expect(summary.sessionsPerWeek, 0);
      // The plan still lists, so the card can offer to start a new block.
      expect(summary.blockCount, 1);
    });

    test('a plan with no blocks at all still appears', () async {
      final summaries = await repository.watchSummaries().first;

      expect(summaries.map((s) => s.plan.id), ['p2', 'p1']);
      expect(summaries.every((s) => s.isActive), isFalse);
    });

    test('an ongoing block is active with no week count', () async {
      await repository.saveBlock(
        block('b1', startDate: today.addDays(-7), durationWeeks: null),
      );

      final summary = await summaryOf('p1');

      expect(summary.isActive, isTrue);
      expect(summary.weekIndex, 1);
      expect(summary.weekCount, isNull);
    });

    test('excludes a deleted plan', () async {
      await repository.deletePlan('p1');

      final summaries = await repository.watchSummaries().first;

      expect(summaries.map((s) => s.plan.id), ['p2']);
    });

    test('re-emits when a block is added', () async {
      final emissions = repository.watchSummaries();

      await repository.saveBlock(block('b1', startDate: today));

      await expectLater(
        emissions,
        emitsThrough(
          predicate<List<PlanSummary>>(
            (list) => list.any((s) => s.isActive),
            'a plan turned active',
          ),
        ),
      );
    });

    test('re-emits when a weekly slot changes', () async {
      await repository.saveBlock(block('b1', startDate: today));
      final emissions = repository.watchSummaries();

      await addSlots('b1', [DateTime.monday]);

      await expectLater(
        emissions,
        emitsThrough(
          predicate<List<PlanSummary>>(
            (list) => list.any((s) => s.sessionsPerWeek == 1),
            'the session count caught up',
          ),
        ),
      );
    });
  });
}
