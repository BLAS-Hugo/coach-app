import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/plan_repository.dart';
import 'package:coach_app/core/repositories/schedule_repository.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repository;
  late PlanRepository plans;

  /// Monday 7 September 2026, which every test treats as today.
  final today = DateOnly(2026, 9, 7);
  final week = DateRange(start: today, end: today.addDays(6));
  final clock = clockAt(DateTime(2026, 9, 7, 10));

  Future<void> writeLog({
    required String id,
    required String planId,
    required DateOnly date,
    required SessionStatus status,
  }) => db
      .into(db.sessionLogs)
      .insert(
        SessionLogsCompanion.insert(
          id: id,
          createdAt: DateTime(2026, 9, 7),
          updatedAt: DateTime(2026, 9, 7),
          planId: planId,
          date: date,
          status: status,
          startedAt: Value(
            status == SessionStatus.skipped ? null : DateTime(2026, 9, 7, 18),
          ),
        ),
      );

  setUp(() async {
    db = openTestDatabase();
    plans = DriftPlanRepository(
      PlanningDao(db, now: clock),
      ContentDao(db, now: clock),
      SchedulingDao(db, now: clock),
    );
    repository = DriftScheduleRepository(SchedulingDao(db, now: clock));

    await plans.savePlan(
      const Plan(id: 'p1', name: 'Upper/Lower', type: PlanType.strength),
    );
    await plans.saveTemplate(
      const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
    );
    await plans.saveBlock(
      TrainingBlock(
        id: 'b1',
        planId: 'p1',
        name: 'Accumulation',
        orderIndex: 0,
        startDate: today,
        durationWeeks: 4,
      ),
    );
    await plans.setSlot(
      const WeeklySlot(
        id: 'sl1',
        blockId: 'b1',
        weekday: DateTime.monday,
        sessionTemplateId: 't1',
      ),
    );
  });

  tearDown(() => db.close());

  group('watchOccurrences', () {
    test('derives an occurrence from the weekly template', () async {
      final occurrences = await repository.watchOccurrences(week).first;

      expect(occurrences, hasLength(1));
      expect(occurrences.single.date, today);
      expect(occurrences.single.sessionTemplateId, 't1');
      expect(occurrences.single.status, OccurrenceStatus.scheduled);
    });

    test('emits again when a slot is added', () async {
      final emissions = repository.watchOccurrences(week);

      await plans.setSlot(
        const WeeklySlot(
          id: 'sl2',
          blockId: 'b1',
          weekday: DateTime.thursday,
          sessionTemplateId: 't1',
        ),
      );

      await expectLater(
        emissions,
        emitsThrough(
          predicate<List<SessionOccurrence>>(
            (list) =>
                list.length == 2 && list.last.date == DateOnly(2026, 9, 10),
            'both Monday and Thursday',
          ),
        ),
      );
    });

    test('emits again when a log is written', () async {
      final emissions = repository.watchOccurrences(week);

      await writeLog(
        id: 'log1',
        planId: 'p1',
        date: today,
        status: SessionStatus.completed,
      );

      await expectLater(
        emissions,
        emitsThrough(
          predicate<List<SessionOccurrence>>(
            (list) =>
                list.single.status == OccurrenceStatus.completed &&
                list.single.sessionLogId == 'log1',
            'the occurrence carries its log',
          ),
        ),
      );
    });

    test('drops a plan that was deleted', () async {
      await plans.deletePlan('p1');

      expect(await repository.watchOccurrences(week).first, isEmpty);
    });
  });

  group('week overrides', () {
    test('a remove override turns the day into a rest day', () async {
      await repository.setOverride(
        const WeekOverride(
          id: 'o1',
          blockId: 'b1',
          weekIndex: 0,
          weekday: DateTime.monday,
          action: WeekOverrideAction.remove,
        ),
      );

      expect(await repository.watchOccurrences(week).first, isEmpty);
    });

    test('an adjustLoad override carries its multiplier', () async {
      await repository.setOverride(
        const WeekOverride(
          id: 'o1',
          blockId: 'b1',
          weekIndex: 0,
          weekday: DateTime.monday,
          action: WeekOverrideAction.adjustLoad,
          loadMultiplier: 0.8,
        ),
      );

      final occurrence = (await repository.watchOccurrences(week).first).single;
      expect(occurrence.loadMultiplier, 0.8);
    });

    test('replaces the override already on that week and weekday', () async {
      await repository.setOverride(
        const WeekOverride(
          id: 'o1',
          blockId: 'b1',
          weekIndex: 0,
          weekday: DateTime.monday,
          action: WeekOverrideAction.remove,
        ),
      );

      await repository.setOverride(
        const WeekOverride(
          id: 'o2',
          blockId: 'b1',
          weekIndex: 0,
          weekday: DateTime.monday,
          action: WeekOverrideAction.adjustLoad,
          loadMultiplier: 0.8,
        ),
      );

      expect(
        (await repository.watchOverrides('b1').first).map((o) => o.id),
        ['o2'],
      );
      expect(
        (await repository.watchOccurrences(week).first).single.loadMultiplier,
        0.8,
      );
    });

    test('clearing an override restores the planned session', () async {
      await repository.setOverride(
        const WeekOverride(
          id: 'o1',
          blockId: 'b1',
          weekIndex: 0,
          weekday: DateTime.monday,
          action: WeekOverrideAction.remove,
        ),
      );

      await repository.clearOverride(
        blockId: 'b1',
        weekIndex: 0,
        weekday: DateTime.monday,
      );

      expect(await repository.watchOccurrences(week).first, hasLength(1));
    });
  });

  group('moves', () {
    test('relocates the occurrence to the target date', () async {
      await repository.moveOccurrence(
        blockId: 'b1',
        from: today,
        to: today.addDays(2),
      );

      final occurrence = (await repository.watchOccurrences(week).first).single;
      expect(occurrence.date, today.addDays(2));
    });

    test(
      'refuses a target already holding a session of the same type',
      () async {
        await plans.setSlot(
          const WeeklySlot(
            id: 'sl2',
            blockId: 'b1',
            weekday: DateTime.wednesday,
            sessionTemplateId: 't1',
          ),
        );

        // Validated at write time: the occurrence engine computes a day's
        // sessions and has no way to report a conflict back to the user
        // (`docs/PLANNING.md` §4).
        await expectLater(
          repository.moveOccurrence(
            blockId: 'b1',
            from: today,
            to: today.addDays(2),
          ),
          throwsA(isA<OccurrenceCollisionException>()),
        );
        expect(
          (await repository.watchOccurrences(week).first).map((o) => o.date),
          [today, today.addDays(2)],
        );
      },
    );

    test('allows a target holding a session of the other type', () async {
      await plans.savePlan(
        const Plan(id: 'p2', name: 'Semi', type: PlanType.endurance),
      );
      await plans.saveTemplate(
        const SessionTemplate(id: 't2', planId: 'p2', name: 'Sortie longue'),
      );
      await plans.saveBlock(
        TrainingBlock(
          id: 'b2',
          planId: 'p2',
          name: 'Base',
          orderIndex: 0,
          startDate: today,
          durationWeeks: 4,
        ),
      );
      await plans.setSlot(
        const WeeklySlot(
          id: 'sl2',
          blockId: 'b2',
          weekday: DateTime.wednesday,
          sessionTemplateId: 't2',
        ),
      );

      await expectLater(
        repository.moveOccurrence(
          blockId: 'b1',
          from: today,
          to: today.addDays(2),
        ),
        completes,
      );
      // A strength and an endurance session may share a day (PRD §5.1).
      expect(await repository.watchOccurrences(week).first, hasLength(2));
    });

    test('moving the same day again replaces the first move', () async {
      await repository.moveOccurrence(
        blockId: 'b1',
        from: today,
        to: today.addDays(2),
      );

      await repository.moveOccurrence(
        blockId: 'b1',
        from: today,
        to: today.addDays(3),
      );

      expect(
        (await repository.watchMoves('b1').first).map((m) => m.targetDate),
        [today.addDays(3)],
      );
      expect(
        (await repository.watchOccurrences(week).first).single.date,
        today.addDays(3),
      );
    });

    test('cancelling a move puts the occurrence back', () async {
      await repository.moveOccurrence(
        blockId: 'b1',
        from: today,
        to: today.addDays(2),
      );

      await repository.cancelMove(blockId: 'b1', date: today);

      expect(
        (await repository.watchOccurrences(week).first).single.date,
        today,
      );
    });
  });

  group('failures', () {
    test('a collision names the day and the type', () {
      expect(
        OccurrenceCollisionException(today, PlanType.strength).toString(),
        allOf(contains('2026-09-07'), contains('strength')),
      );
    });

    test('a broken read surfaces on the stream', () async {
      final emissions = repository.watchOccurrences(week);

      // Losing a table mid-session is not a scenario the app creates, but a
      // stream that dies silently would leave the day view frozen on stale
      // occurrences with no way to tell.
      await db.customStatement('DROP TABLE week_overrides');
      db.notifyUpdates({TableUpdate.onTable(db.plans)});

      await expectLater(emissions, emitsThrough(emitsError(anything)));
    });
  });
}
