import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/bloc/week_template_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeekTemplateEvent', () {
    final start = DateOnly(2026, 9, 7);

    // Pairs built twice from the same arguments must be equal, and a
    // different argument must break the equality — which is what lets
    // bloc_test compare them and what keeps `props` honest.
    final cases = <String, (Object Function(), Object)>{
      'subscription': (
        () => const WeekTemplateSubscriptionRequested(),
        const WeekTemplateUndoRequested(),
      ),
      'assigned': (
        () => const WeekTemplateSessionAssigned(weekday: 1, templateId: 't1'),
        const WeekTemplateSessionAssigned(weekday: 1, templateId: 't2'),
      ),
      'created': (
        () => const WeekTemplateSessionCreated(weekday: 1, name: 'Haut'),
        const WeekTemplateSessionCreated(weekday: 2, name: 'Haut'),
      ),
      'cleared': (
        () => const WeekTemplateDayCleared(weekday: 1),
        const WeekTemplateDayCleared(weekday: 2),
      ),
      'moved': (
        () => const WeekTemplateSessionMoved(from: 1, to: 2),
        const WeekTemplateSessionMoved(from: 2, to: 1),
      ),
      'duration': (
        () => const WeekTemplateDurationChanged(weeks: 4),
        const WeekTemplateDurationChanged(weeks: 5),
      ),
      'stopped': (
        () => const WeekTemplateBlockStopped(),
        const WeekTemplateUndoRequested(),
      ),
      'block created': (
        () => WeekTemplateBlockCreated(
          name: 'Bloc 1',
          startDate: start,
          durationWeeks: 4,
        ),
        WeekTemplateBlockCreated(
          name: 'Bloc 1',
          startDate: start.addDays(1),
          durationWeeks: 4,
        ),
      ),
      'duplicated': (
        () => const WeekTemplateWeekDuplicated(name: 'Bloc 2'),
        const WeekTemplateWeekDuplicated(name: 'Bloc 3'),
      ),
      'undo': (
        () => const WeekTemplateUndoRequested(),
        const WeekTemplateBlockStopped(),
      ),
    };

    test('events without arguments have no props', () {
      expect(const WeekTemplateSubscriptionRequested().props, isEmpty);
      expect(const WeekTemplateBlockStopped().props, isEmpty);
      expect(const WeekTemplateUndoRequested().props, isEmpty);
    });

    for (final MapEntry(key: name, value: (make, other)) in cases.entries) {
      test('$name compares by value', () {
        expect(make(), make());
        expect(make(), isNot(other));
      });
    }
  });
}
