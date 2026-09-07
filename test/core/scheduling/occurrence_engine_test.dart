import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/scheduling/occurrence_engine.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-08-17 is a Monday, which keeps the weekday arithmetic readable.
final monday = DateOnly(2026, 8, 17);

Plan _plan({
  String id = 'plan-s',
  PlanType type = PlanType.strength,
}) => Plan(id: id, name: 'Upper/Lower', type: type);

TrainingBlock _block({
  String id = 'block-1',
  String planId = 'plan-s',
  DateOnly? startDate,
  int? durationWeeks = 4,
  DateOnly? explicitEndDate,
  int orderIndex = 0,
}) => TrainingBlock(
  id: id,
  planId: planId,
  name: 'Accumulation',
  orderIndex: orderIndex,
  startDate: startDate ?? monday,
  durationWeeks: durationWeeks,
  explicitEndDate: explicitEndDate,
);

WeeklySlot _slot({
  required int weekday,
  String id = 'slot-1',
  String blockId = 'block-1',
  String templateId = 'tpl-upper',
}) => WeeklySlot(
  id: id,
  blockId: blockId,
  weekday: weekday,
  sessionTemplateId: templateId,
);

SchedulingInput _input({
  List<Plan>? plans,
  Map<String, List<TrainingBlock>>? blocksByPlan,
  Map<String, List<WeeklySlot>>? slotsByBlock,
  Map<String, List<WeekOverride>> overridesByBlock = const {},
  Map<String, List<OccurrenceException>> exceptionsByBlock = const {},
  List<SessionLog> logs = const [],
  DateOnly? today,
}) => SchedulingInput(
  plans: plans ?? [_plan()],
  blocksByPlan:
      blocksByPlan ??
      {
        'plan-s': [_block()],
      },
  slotsByBlock:
      slotsByBlock ??
      {
        'block-1': [_slot(weekday: DateTime.monday)],
      },
  overridesByBlock: overridesByBlock,
  exceptionsByBlock: exceptionsByBlock,
  logs: logs,
  today: today ?? monday,
);

List<SessionOccurrence> _run(SchedulingInput input, DateRange range) =>
    OccurrenceEngine.computeOccurrences(input: input, range: range);

void main() {
  group('OccurrenceEngine', () {
    group('the weekly template', () {
      test('emits one occurrence per matching weekday', () {
        final result = _run(_input(), DateRange.days(monday, 28));
        expect(result.length, 4);
        expect(
          result.map((o) => o.date).toList(),
          [monday, monday.addWeeks(1), monday.addWeeks(2), monday.addWeeks(3)],
        );
        expect(result.every((o) => o.sessionTemplateId == 'tpl-upper'), isTrue);
      });

      test('emits nothing on a weekday with no slot', () {
        final result = _run(_input(), DateRange.days(monday.addDays(1), 6));
        expect(result, isEmpty);
      });

      test('emits nothing when the block has no weekly template at all', () {
        final result = _run(
          _input(slotsByBlock: const {}),
          DateRange.days(monday, 28),
        );
        expect(result, isEmpty);
      });

      test('handles several slots in one week', () {
        final result = _run(
          _input(
            slotsByBlock: {
              'block-1': [
                _slot(id: 's1', weekday: DateTime.monday, templateId: 'upper'),
                _slot(id: 's2', weekday: DateTime.thursday, templateId: 'low'),
              ],
            },
          ),
          DateRange.days(monday, 7),
        );
        expect(result.length, 2);
        expect(result[0].date.weekday, DateTime.monday);
        expect(result[1].date.weekday, DateTime.thursday);
        expect(result[1].sessionTemplateId, 'low');
      });

      test('emits nothing for a plan with no blocks', () {
        final result = _run(
          _input(blocksByPlan: const {}),
          DateRange.days(monday, 28),
        );
        expect(result, isEmpty);
      });
    });

    group('block boundaries', () {
      test('emits nothing before the block starts', () {
        final result = _run(_input(), DateRange.days(monday.addWeeks(-4), 28));
        expect(result, isEmpty);
      });

      test('emits nothing after a derived end date', () {
        // 4 weeks from Monday 17 Aug ends Sunday 13 Sep.
        final result = _run(_input(), DateRange.days(monday, 56));
        expect(result.length, 4);
        expect(result.last.date, monday.addWeeks(3));
      });

      test('a derived end date is start + weeks × 7 − 1', () {
        expect(_block().endDate, monday.addDays(27));
        expect(_block(durationWeeks: 1).endDate, monday.addDays(6));
      });

      test('an explicit end date wins, even when it shortens the block', () {
        final stopped = _block(explicitEndDate: monday.addDays(13));
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [stopped],
            },
          ),
          DateRange.days(monday, 56),
        );
        expect(result.length, 2);
        expect(result.last.date, monday.addWeeks(1));
      });

      test('an explicit end date wins when it extends the block too', () {
        final extended = _block(explicitEndDate: monday.addDays(41));
        expect(extended.endDate, monday.addDays(41));
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [extended],
            },
          ),
          DateRange.days(monday, 56),
        );
        expect(result.length, 6);
      });

      test('a null duration and null end date schedules indefinitely', () {
        final ongoing = _block(durationWeeks: null);
        expect(ongoing.isOngoing, isTrue);
        expect(ongoing.endDate, isNull);
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [ongoing],
            },
            today: monday,
          ),
          DateRange.days(monday, 365),
        );
        expect(result.length, 53);
      });

      test('an ongoing block still respects its start date', () {
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(durationWeeks: null)],
            },
          ),
          DateRange.days(monday.addWeeks(-2), 21),
        );
        expect(result.length, 1);
        expect(result.single.date, monday);
      });

      test('an ongoing block schedules in a window long after its start', () {
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(durationWeeks: null)],
            },
            today: monday,
          ),
          DateRange.days(monday.addWeeks(60), 21),
        );
        expect(result.length, 3);
        expect(result.first.date, monday.addWeeks(60));
        expect(
          result.every((o) => o.status == OccurrenceStatus.scheduled),
          isTrue,
        );
      });

      test('an ongoing block starting after the window emits nothing', () {
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [
                _block(
                  startDate: monday.addWeeks(10),
                  durationWeeks: null,
                ),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result, isEmpty);
      });

      test('a block entirely outside the window emits nothing', () {
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(startDate: DateOnly(2027))],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result, isEmpty);
      });
    });

    group('partial first week', () {
      // A block starting on a Thursday has a week 0 of Thu–Wed.
      final thursday = DateOnly(2026, 8, 20);

      test('week 0 is the partial week beginning on the start date', () {
        final block = _block(startDate: thursday, durationWeeks: 5);
        expect(block.weekIndexOf(thursday), 0);
        expect(block.weekIndexOf(thursday.addDays(6)), 0);
        expect(block.weekIndexOf(thursday.addDays(7)), 1);
      });

      test('a Monday slot first fires in week 0 only if it is covered', () {
        // Starting Thursday, the first Monday is 4 days later, still week 0.
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(startDate: thursday, durationWeeks: 3)],
            },
          ),
          DateRange.days(thursday, 21),
        );
        expect(result.first.date, thursday.addDays(4));
        expect(
          _block(startDate: thursday).weekIndexOf(result.first.date),
          0,
        );
      });

      test('a week index before the block start is negative, not zero', () {
        final block = _block(startDate: thursday);
        expect(block.weekIndexOf(thursday.addDays(-1)), -1);
        expect(block.weekIndexOf(thursday.addDays(-7)), -1);
        expect(block.weekIndexOf(thursday.addDays(-8)), -2);
      });

      test('weekCount counts partial weeks at both ends', () {
        expect(_block().weekCount, 4);
        expect(
          _block(startDate: thursday, explicitEndDate: thursday).weekCount,
          1,
        );
        expect(_block(durationWeeks: null).weekCount, isNull);
      });
    });

    group('DST', () {
      // Europe/Paris springs forward 2026-03-29 and falls back 2026-10-25.
      test('a weekly slot does not drift across a spring-forward', () {
        final start = DateOnly(2026, 3, 2); // Monday, four weeks before.
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(startDate: start, durationWeeks: 8)],
            },
            slotsByBlock: {
              'block-1': [_slot(weekday: DateTime.monday)],
            },
            today: start,
          ),
          DateRange.days(start, 56),
        );
        expect(result.length, 8);
        expect(result.every((o) => o.date.weekday == DateTime.monday), isTrue);
        expect(result.map((o) => o.date), contains(DateOnly(2026, 3, 30)));
      });

      test('a weekly slot does not drift across a fall-back', () {
        final start = DateOnly(2026, 10, 5);
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(startDate: start, durationWeeks: 6)],
            },
            today: start,
          ),
          DateRange.days(start, 42),
        );
        expect(result.length, 6);
        expect(result.every((o) => o.date.weekday == DateTime.monday), isTrue);
        expect(result.map((o) => o.date), contains(DateOnly(2026, 10, 26)));
      });

      test('week indices stay contiguous across a transition', () {
        final start = DateOnly(2026, 3, 2);
        final block = _block(startDate: start, durationWeeks: 8);
        final seen = [
          for (var w = 0; w < 8; w++) block.weekIndexOf(start.addWeeks(w)),
        ];
        expect(seen, [0, 1, 2, 3, 4, 5, 6, 7]);
      });
    });

    group('week overrides', () {
      WeekOverride override({
        required WeekOverrideAction action,
        int weekIndex = 2,
        int weekday = DateTime.monday,
        String? replacementId,
        double? multiplier,
      }) => WeekOverride(
        id: 'ovr',
        blockId: 'block-1',
        weekIndex: weekIndex,
        weekday: weekday,
        action: action,
        replacementSessionTemplateId: replacementId,
        loadMultiplier: multiplier,
      );

      test('remove turns that one week into a rest day', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [override(action: WeekOverrideAction.remove)],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.length, 3);
        expect(result.map((o) => o.date), isNot(contains(monday.addWeeks(2))));
      });

      test('replace swaps the template for that week only', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [
                override(
                  action: WeekOverrideAction.replace,
                  replacementId: 'tpl-deload',
                ),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.length, 4);
        expect(result[2].sessionTemplateId, 'tpl-deload');
        expect(result[0].sessionTemplateId, 'tpl-upper');
        expect(result[3].sessionTemplateId, 'tpl-upper');
      });

      test('replace with no replacement id leaves the template alone', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [override(action: WeekOverrideAction.replace)],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result[2].sessionTemplateId, 'tpl-upper');
      });

      test('adjustLoad carries the multiplier, PRD §6.3 deload', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [
                override(
                  action: WeekOverrideAction.adjustLoad,
                  weekIndex: 3,
                  multiplier: 0.8,
                ),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result[3].loadMultiplier, 0.8);
        expect(result[0].loadMultiplier, isNull);
      });

      test('an override for another weekday does not apply', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [
                override(
                  action: WeekOverrideAction.remove,
                  weekday: DateTime.friday,
                ),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.length, 4);
      });

      test('an override for another week does not apply', () {
        final result = _run(
          _input(
            overridesByBlock: {
              'block-1': [
                override(action: WeekOverrideAction.remove, weekIndex: 9),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.length, 4);
      });
    });

    group('occurrence exceptions', () {
      OccurrenceException exception({
        required OccurrenceExceptionKind kind,
        DateOnly? date,
        DateOnly? targetDate,
      }) => OccurrenceException(
        id: 'exc',
        blockId: 'block-1',
        date: date ?? monday.addWeeks(1),
        kind: kind,
        targetDate: targetDate,
      );

      test('skip marks that occurrence skipped but still emits it', () {
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [exception(kind: OccurrenceExceptionKind.skip)],
            },
            today: monday,
          ),
          DateRange.days(monday, 28),
        );
        expect(result.length, 4);
        expect(result[1].status, OccurrenceStatus.skipped);
        expect(result[0].status, OccurrenceStatus.scheduled);
      });

      test('move emits the occurrence at the target date instead', () {
        final moved = monday.addWeeks(1).addDays(2);
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [
                exception(
                  kind: OccurrenceExceptionKind.move,
                  targetDate: moved,
                ),
              ],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.map((o) => o.date), contains(moved));
        expect(
          result.map((o) => o.date),
          isNot(contains(monday.addWeeks(1))),
        );
      });

      test('move with a null target leaves the date alone', () {
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [exception(kind: OccurrenceExceptionKind.move)],
            },
          ),
          DateRange.days(monday, 28),
        );
        expect(result.map((o) => o.date), contains(monday.addWeeks(1)));
      });

      test('an occurrence moved out of the window disappears from it', () {
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [
                exception(
                  date: monday,
                  kind: OccurrenceExceptionKind.move,
                  targetDate: monday.addWeeks(3),
                ),
              ],
            },
          ),
          DateRange.days(monday, 7),
        );
        expect(result, isEmpty);
      });

      test('an occurrence moved into the window appears in it', () {
        // Source Monday is outside the window; its target is inside.
        final target = monday.addWeeks(1).addDays(2);
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [
                exception(
                  date: monday.addWeeks(1),
                  kind: OccurrenceExceptionKind.move,
                  targetDate: target,
                ),
              ],
            },
          ),
          DateRange(start: target.addDays(-1), end: target.addDays(1)),
        );
        expect(result.length, 1);
        expect(result.single.date, target);
      });
    });

    group('status resolution', () {
      SessionLog log({
        required SessionStatus status,
        DateOnly? date,
        String planId = 'plan-s',
      }) => SessionLog(
        id: 'log-1',
        planId: planId,
        date: date ?? monday,
        status: status,
        startedAt: DateTime(2026, 8, 17, 18),
      );

      test('a future date with no log is scheduled', () {
        final result = _run(
          _input(today: monday),
          DateRange.days(monday, 28),
        );
        expect(result.first.status, OccurrenceStatus.scheduled);
        expect(result.first.sessionLogId, isNull);
      });

      test('today with no log is scheduled, not missed', () {
        final result = _run(
          _input(today: monday),
          DateRange.days(monday, 1),
        );
        expect(result.single.status, OccurrenceStatus.scheduled);
      });

      test('a past date with no log is missed', () {
        final result = _run(
          _input(today: monday.addWeeks(2)),
          DateRange.days(monday, 28),
        );
        expect(result[0].status, OccurrenceStatus.missed);
        expect(result[1].status, OccurrenceStatus.missed);
        expect(result[2].status, OccurrenceStatus.scheduled);
      });

      test('a log outranks the date-derived status', () {
        for (final (logStatus, expected) in [
          (SessionStatus.inProgress, OccurrenceStatus.inProgress),
          (SessionStatus.completed, OccurrenceStatus.completed),
          (SessionStatus.skipped, OccurrenceStatus.skipped),
        ]) {
          final result = _run(
            _input(
              logs: [log(status: logStatus)],
              today: monday.addWeeks(2),
            ),
            DateRange.days(monday, 7),
          );
          expect(result.single.status, expected, reason: '$logStatus');
          expect(result.single.sessionLogId, 'log-1');
        }
      });

      test('a log beats a user skip exception', () {
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [
                OccurrenceException(
                  id: 'exc',
                  blockId: 'block-1',
                  date: monday,
                  kind: OccurrenceExceptionKind.skip,
                ),
              ],
            },
            logs: [log(status: SessionStatus.completed)],
          ),
          DateRange.days(monday, 7),
        );
        expect(result.single.status, OccurrenceStatus.completed);
      });

      test('a log for another plan does not attach', () {
        final result = _run(
          _input(
            logs: [log(status: SessionStatus.completed, planId: 'other')],
          ),
          DateRange.days(monday, 7),
        );
        expect(result.single.sessionLogId, isNull);
      });

      test('a log on another date does not attach', () {
        final result = _run(
          _input(
            logs: [log(status: SessionStatus.completed, date: monday)],
          ),
          DateRange.days(monday.addWeeks(1), 7),
        );
        expect(result.single.sessionLogId, isNull);
      });

      test('a log follows a moved occurrence to its new date', () {
        final target = monday.addDays(2);
        final result = _run(
          _input(
            exceptionsByBlock: {
              'block-1': [
                OccurrenceException(
                  id: 'exc',
                  blockId: 'block-1',
                  date: monday,
                  kind: OccurrenceExceptionKind.move,
                  targetDate: target,
                ),
              ],
            },
            logs: [log(status: SessionStatus.completed, date: target)],
          ),
          DateRange.days(monday, 7),
        );
        expect(result.single.date, target);
        expect(result.single.status, OccurrenceStatus.completed);
      });
    });

    group('two concurrent plans', () {
      test('a day can hold one strength and one endurance session', () {
        final result = _run(
          SchedulingInput(
            plans: [
              _plan(id: 'plan-e', type: PlanType.endurance),
              _plan(),
            ],
            blocksByPlan: {
              'plan-s': [_block()],
              'plan-e': [_block(id: 'block-e', planId: 'plan-e')],
            },
            slotsByBlock: {
              'block-1': [_slot(weekday: DateTime.monday)],
              'block-e': [
                _slot(
                  id: 'slot-e',
                  blockId: 'block-e',
                  weekday: DateTime.monday,
                  templateId: 'tpl-intervals',
                ),
              ],
            },
            today: monday,
          ),
          DateRange.days(monday, 7),
        );

        expect(result.length, 2);
        // Strength sorts before endurance, matching the date-strip tracks.
        expect(result[0].type, PlanType.strength);
        expect(result[1].type, PlanType.endurance);
        expect(result[1].sessionTemplateId, 'tpl-intervals');
        expect(result.map((o) => o.date).toSet(), {monday});
      });

      test('the two plans keep independent week indices', () {
        // The endurance block starts a week later, so on the same date it is
        // a week behind the strength block.
        final result = _run(
          SchedulingInput(
            plans: [
              _plan(),
              _plan(id: 'plan-e', type: PlanType.endurance),
            ],
            blocksByPlan: {
              'plan-s': [_block()],
              'plan-e': [
                _block(
                  id: 'block-e',
                  planId: 'plan-e',
                  startDate: monday.addWeeks(1),
                ),
              ],
            },
            slotsByBlock: {
              'block-1': [_slot(weekday: DateTime.monday)],
              'block-e': [
                _slot(
                  id: 'slot-e',
                  blockId: 'block-e',
                  weekday: DateTime.monday,
                ),
              ],
            },
            overridesByBlock: {
              // Week 1 of each block, which is a different calendar week.
              'block-1': [
                const WeekOverride(
                  id: 'o1',
                  blockId: 'block-1',
                  weekIndex: 1,
                  weekday: DateTime.monday,
                  action: WeekOverrideAction.remove,
                ),
              ],
              'block-e': [
                const WeekOverride(
                  id: 'o2',
                  blockId: 'block-e',
                  weekIndex: 1,
                  weekday: DateTime.monday,
                  action: WeekOverrideAction.remove,
                ),
              ],
            },
            today: monday,
          ),
          DateRange.days(monday, 28),
        );

        final strengthDates = result
            .where((o) => o.type == PlanType.strength)
            .map((o) => o.date);
        final enduranceDates = result
            .where((o) => o.type == PlanType.endurance)
            .map((o) => o.date);
        expect(strengthDates, isNot(contains(monday.addWeeks(1))));
        expect(enduranceDates, contains(monday.addWeeks(1)));
        expect(enduranceDates, isNot(contains(monday.addWeeks(2))));
      });
    });

    group('consecutive blocks in one plan', () {
      test('each block restarts its week index at zero', () {
        final second = _block(
          id: 'block-2',
          startDate: monday.addWeeks(4),
          orderIndex: 1,
        );
        expect(second.weekIndexOf(monday.addWeeks(4)), 0);
        expect(second.weekIndexOf(monday.addWeeks(6)), 2);

        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [_block(), second],
            },
            slotsByBlock: {
              'block-1': [_slot(weekday: DateTime.monday)],
              'block-2': [
                _slot(
                  id: 'slot-2',
                  blockId: 'block-2',
                  weekday: DateTime.monday,
                  templateId: 'tpl-intensification',
                ),
              ],
            },
            // Week 0 of the second block, not of the plan.
            overridesByBlock: {
              'block-2': [
                const WeekOverride(
                  id: 'o',
                  blockId: 'block-2',
                  weekIndex: 0,
                  weekday: DateTime.monday,
                  action: WeekOverrideAction.remove,
                ),
              ],
            },
          ),
          DateRange.days(monday, 56),
        );

        expect(result.length, 7);
        expect(result.map((o) => o.date), isNot(contains(monday.addWeeks(4))));
        expect(
          result.where((o) => o.blockId == 'block-2').length,
          3,
        );
        expect(
          result.last.sessionTemplateId,
          'tpl-intensification',
        );
      });

      test('a gap between two blocks schedules nothing', () {
        final result = _run(
          _input(
            blocksByPlan: {
              'plan-s': [
                _block(durationWeeks: 2),
                _block(
                  id: 'block-2',
                  startDate: monday.addWeeks(4),
                  durationWeeks: 2,
                  orderIndex: 1,
                ),
              ],
            },
            slotsByBlock: {
              'block-1': [_slot(weekday: DateTime.monday)],
              'block-2': [
                _slot(id: 's2', blockId: 'block-2', weekday: DateTime.monday),
              ],
            },
          ),
          DateRange.days(monday, 42),
        );
        expect(result.map((o) => o.date), [
          monday,
          monday.addWeeks(1),
          monday.addWeeks(4),
          monday.addWeeks(5),
        ]);
      });

      test('overlaps detects blocks that would collide', () {
        final first = _block();
        expect(
          first.overlaps(_block(id: 'b2', startDate: monday.addDays(27))),
          isTrue,
        );
        expect(
          first.overlaps(_block(id: 'b2', startDate: monday.addDays(28))),
          isFalse,
        );
        // An ongoing block collides with anything starting after it.
        final ongoing = _block(durationWeeks: null);
        expect(
          ongoing.overlaps(_block(id: 'b2', startDate: monday.addWeeks(52))),
          isTrue,
        );
      });
    });

    group('ordering and shape of the result', () {
      test('is sorted by date', () {
        final result = _run(_input(), DateRange.days(monday, 28));
        for (var i = 1; i < result.length; i++) {
          expect(result[i].date.isBefore(result[i - 1].date), isFalse);
        }
      });

      test('carries plan, block and type through onto every occurrence', () {
        final result = _run(_input(), DateRange.days(monday, 7));
        final occurrence = result.single;
        expect(occurrence.planId, 'plan-s');
        expect(occurrence.blockId, 'block-1');
        expect(occurrence.type, PlanType.strength);
        expect(occurrence.isMaterialised, isFalse);
        expect(occurrence.isStartable, isTrue);
      });

      test('a completed occurrence is materialised and not startable', () {
        final result = _run(
          _input(
            logs: [
              SessionLog(
                id: 'log-1',
                planId: 'plan-s',
                date: monday,
                status: SessionStatus.completed,
                startedAt: DateTime(2026, 8, 17, 18),
              ),
            ],
          ),
          DateRange.days(monday, 7),
        );
        expect(result.single.isMaterialised, isTrue);
        expect(result.single.isStartable, isFalse);
      });

      test('an empty plan list yields nothing', () {
        final result = _run(
          _input(plans: const []),
          DateRange.days(monday, 28),
        );
        expect(result, isEmpty);
      });

      test('is a pure function — same input, same output', () {
        final input = _input();
        final range = DateRange.days(monday, 28);
        expect(_run(input, range), _run(input, range));
      });
    });

    group('TrainingBlock derived state', () {
      test('statusOn places the block relative to a day', () {
        final block = _block();
        expect(
          block.statusOn(monday.addDays(-1)),
          TrainingBlockStatus.upcoming,
        );
        expect(block.statusOn(monday), TrainingBlockStatus.active);
        expect(block.statusOn(monday.addDays(27)), TrainingBlockStatus.active);
        expect(
          block.statusOn(monday.addDays(28)),
          TrainingBlockStatus.finished,
        );
      });

      test('an ongoing block is never finished', () {
        final ongoing = _block(durationWeeks: null);
        expect(
          ongoing.statusOn(monday.addWeeks(500)),
          TrainingBlockStatus.active,
        );
      });

      test('dateRange is null while the block is ongoing', () {
        expect(_block(durationWeeks: null).dateRange, isNull);
        expect(
          _block().dateRange,
          DateRange(start: monday, end: monday.addDays(27)),
        );
      });

      test('covers is inclusive at both ends', () {
        final block = _block();
        expect(block.covers(monday.addDays(-1)), isFalse);
        expect(block.covers(monday), isTrue);
        expect(block.covers(monday.addDays(27)), isTrue);
        expect(block.covers(monday.addDays(28)), isFalse);
      });
    });
  });
}
