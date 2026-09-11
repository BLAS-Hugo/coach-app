import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plan = Plan(id: 'p1', name: 'Haut / bas', type: PlanType.strength);

  /// A Monday.
  final today = DateOnly(2026, 9, 7);

  TrainingBlock block(
    String id, {
    required DateOnly startDate,
    int? durationWeeks = 5,
    DateOnly? explicitEndDate,
  }) => TrainingBlock(
    id: id,
    planId: 'p1',
    name: 'Intensification',
    orderIndex: 0,
    startDate: startDate,
    durationWeeks: durationWeeks,
    explicitEndDate: explicitEndDate,
  );

  WeekTemplate weekWith(TrainingBlock? current, {List<TrainingBlock>? all}) =>
      WeekTemplate(
        plan: plan,
        today: today,
        block: current,
        blocks: all ?? [?current],
      );

  group('SessionTemplateSummary', () {
    const template = SessionTemplate(id: 't1', planId: 'p1', name: 'Haut');

    test('is empty with no content of either kind', () {
      expect(const SessionTemplateSummary(template: template).isEmpty, isTrue);
    });

    for (final summary in const [
      SessionTemplateSummary(template: template, exerciseCount: 1),
      SessionTemplateSummary(template: template, setCount: 1),
      SessionTemplateSummary(template: template, enduranceBlockCount: 1),
    ]) {
      test('is not empty with $summary', () {
        expect(summary.isEmpty, isFalse);
      });
    }
  });

  group('WeekTemplate', () {
    group('blockOrdinal', () {
      test('is null without a block', () {
        expect(weekWith(null).blockOrdinal, isNull);
      });

      test('numbers the block 1-based among its siblings', () {
        final first = block('b1', startDate: today.addDays(-70));
        final second = block('b2', startDate: today);

        expect(weekWith(second, all: [first, second]).blockOrdinal, 2);
      });

      test('is null when the block is not among them', () {
        final stray = block('b9', startDate: today);

        expect(weekWith(stray, all: const []).blockOrdinal, isNull);
      });
    });

    test('finds the slot on a weekday, or none for a rest day', () {
      const slot = WeeklySlot(
        id: 's1',
        blockId: 'b1',
        weekday: DateTime.wednesday,
        sessionTemplateId: 't1',
      );
      final week = weekWith(null).copyWith(slots: const [slot]);

      expect(week.slotOn(DateTime.wednesday), slot);
      expect(week.slotOn(DateTime.thursday), isNull);
    });

    test('finds a template by id, or none once it is gone', () {
      const summary = SessionTemplateSummary(
        template: SessionTemplate(id: 't1', planId: 'p1', name: 'Haut'),
      );
      final week = weekWith(null).copyWith(templates: const [summary]);

      expect(week.templateById('t1'), summary);
      expect(week.templateById('t2'), isNull);
    });

    group('isEditable', () {
      test('is false without a block', () {
        expect(weekWith(null).isEditable, isFalse);
        expect(weekWith(null).blockStatus, isNull);
      });

      test('is true for a running block', () {
        expect(weekWith(block('b1', startDate: today)).isEditable, isTrue);
      });

      test('is true for a block still to come', () {
        final upcoming = block('b1', startDate: today.addDays(7));

        expect(weekWith(upcoming).isEditable, isTrue);
      });

      test('is false for a finished block', () {
        final finished = block('b1', startDate: today.addDays(-70));

        expect(weekWith(finished).isEditable, isFalse);
      });
    });

    group('stopDate', () {
      test('is the last day of the block week today falls in', () {
        // Started on a Thursday, so its weeks run Thursday to Wednesday:
        // today, a Monday, ends the week on Wednesday the 9th.
        final running = block('b1', startDate: DateOnly(2026, 8, 27));

        expect(weekWith(running).stopDate, DateOnly(2026, 9, 9));
      });

      test('is null when the block already ends that week', () {
        final ending = block(
          'b1',
          startDate: today,
          explicitEndDate: today.addDays(6),
        );

        expect(weekWith(ending).stopDate, isNull);
      });

      test('is set for an ongoing block', () {
        final ongoing = block('b1', startDate: today, durationWeeks: null);

        expect(weekWith(ongoing).stopDate, today.addDays(6));
      });

      test('is null for a block not running today', () {
        expect(weekWith(null).stopDate, isNull);
        expect(
          weekWith(block('b1', startDate: today.addDays(7))).stopDate,
          isNull,
        );
      });
    });

    group('minDurationWeeks', () {
      test('keeps a running block from ending before this week', () {
        final running = block('b1', startDate: today.addDays(-14));

        expect(weekWith(running).minDurationWeeks, 3);
      });

      test('is one week otherwise', () {
        expect(weekWith(null).minDurationWeeks, 1);
        expect(
          weekWith(block('b1', startDate: today.addDays(7))).minDurationWeeks,
          1,
        );
      });
    });

    group('canDuplicate', () {
      test('is true for a block with an end', () {
        expect(weekWith(block('b1', startDate: today)).canDuplicate, isTrue);
      });

      test('is false for an ongoing block or none', () {
        final ongoing = block('b1', startDate: today, durationWeeks: null);

        expect(weekWith(ongoing).canDuplicate, isFalse);
        expect(weekWith(null).canDuplicate, isFalse);
      });
    });
  });
}
