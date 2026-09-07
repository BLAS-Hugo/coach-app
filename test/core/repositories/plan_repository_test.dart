import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/plan_repository.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repository;

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
    String planId = 'p1',
    required DateOnly startDate,
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
    repository = DriftPlanRepository(
      PlanningDao(db, now: clockAt(DateTime(2026, 9, 7, 10))),
    );
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

    test('deleting a plan cascades to its blocks, templates and slots', () async {
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
    });
  });

  group('blocks', () {
    test('orders blocks chronologically', () async {
      await repository.saveBlock(
        block('b2', startDate: DateOnly(2026, 10, 5), orderIndex: 100),
      );
      await repository.saveBlock(
        block('b1', startDate: DateOnly(2026, 9, 7), orderIndex: 0),
      );

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
      await repository.saveBlock(
        block('b1', startDate: DateOnly(2026, 9, 14)),
      );
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
        repository.saveBlock(block('b2', startDate: DateOnly(2027, 1, 1))),
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
      await repository.saveBlock(
        block('b1', startDate: DateOnly(2026, 9, 8)),
      );

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

      expect(
        (await repository.watchTemplates('p1').first).map((t) => t.id),
        ['t1'],
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

      expect(
        (await repository.watchSlots('b1').first).map((s) => s.id),
        ['s2', 's1'],
      );
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
}
