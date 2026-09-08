import 'package:coach_app/core/utils/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateOnly', () {
    test('exposes the calendar fields it was built from', () {
      final date = DateOnly(2026, 8, 19);
      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 19);
      expect(date.weekday, DateTime.wednesday);
    });

    test('defaults month and day to the first of January', () {
      expect(DateOnly(2026).toString(), '2026-01-01');
      expect(DateOnly(2026, 3).toString(), '2026-03-01');
    });

    test('normalises out-of-range months and days like DateTime', () {
      expect(DateOnly(2026, 1, 32).toString(), '2026-02-01');
      expect(DateOnly(2026, 13).toString(), '2027-01-01');
      expect(DateOnly(2026, 3, 0).toString(), '2026-02-28');
    });

    test('epochDay counts from 1970-01-01', () {
      expect(DateOnly(1970).epochDay, 0);
      expect(DateOnly(1970, 1, 2).epochDay, 1);
      expect(DateOnly(1969, 12, 31).epochDay, -1);
      expect(DateOnly(1969, 12, 30).epochDay, -2);
    });

    test('round-trips through toString and parse', () {
      for (final date in [
        DateOnly(2026, 8, 19),
        DateOnly(1969, 7, 20),
        DateOnly(2000, 2, 29),
      ]) {
        expect(DateOnly.parse(date.toString()), date);
      }
    });

    test('parse rejects anything that is not a bare calendar date', () {
      for (final bad in [
        '2026-08-19T00:00:00Z',
        '2026-8-19',
        '19/08/2026',
        '',
        'today',
      ]) {
        expect(() => DateOnly.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('fromDateTime discards the time component', () {
      final noon = DateTime(2026, 8, 19, 12, 30, 45, 123);
      expect(DateOnly.fromDateTime(noon), DateOnly(2026, 8, 19));
      final lateEvening = DateTime(2026, 8, 19, 23, 59, 59);
      expect(DateOnly.fromDateTime(lateEvening), DateOnly(2026, 8, 19));
    });

    test('today reads the injected clock, never the wall clock', () {
      expect(
        DateOnly.today(clock: () => DateTime(2026, 8, 19, 6)),
        DateOnly(2026, 8, 19),
      );
    });

    group('arithmetic', () {
      test('addDays crosses month and year boundaries', () {
        expect(DateOnly(2026, 8, 31).addDays(1), DateOnly(2026, 9));
        expect(DateOnly(2026, 12, 31).addDays(1), DateOnly(2027));
        expect(DateOnly(2026).addDays(-1), DateOnly(2025, 12, 31));
      });

      test('addDays handles leap years', () {
        expect(DateOnly(2024, 2, 28).addDays(1), DateOnly(2024, 2, 29));
        expect(DateOnly(2025, 2, 28).addDays(1), DateOnly(2025, 3));
        // 1900 was not a leap year; 2000 was.
        expect(DateOnly(1900, 2, 28).addDays(1), DateOnly(1900, 3));
        expect(DateOnly(2000, 2, 28).addDays(1), DateOnly(2000, 2, 29));
      });

      test('addWeeks lands on the same weekday', () {
        final start = DateOnly(2026, 8, 19);
        for (var weeks = 0; weeks < 60; weeks++) {
          expect(start.addWeeks(weeks).weekday, start.weekday);
        }
      });

      test('differenceInDays is signed and exact', () {
        expect(
          DateOnly(2026, 8, 26).differenceInDays(DateOnly(2026, 8, 19)),
          7,
        );
        expect(
          DateOnly(2026, 8, 19).differenceInDays(DateOnly(2026, 8, 26)),
          -7,
        );
        expect(DateOnly(2027).differenceInDays(DateOnly(2026)), 365);
      });

      test('addDays and differenceInDays invert each other', () {
        final start = DateOnly(2026, 3);
        for (final offset in [-400, -31, -1, 0, 1, 31, 400]) {
          expect(start.addDays(offset).differenceInDays(start), offset);
        }
      });
    });

    group('DST — the reason this type exists', () {
      // Europe/Paris springs forward on 2026-03-29 and falls back on
      // 2026-10-25. These assertions hold in any zone, because DateOnly
      // never touches a wall clock; the paired DateTime assertions below
      // only hold where the test runs in a zone with these transitions,
      // so they are not asserted — the comments record the trap.
      test('a day either side of a spring-forward is exactly one day', () {
        final before = DateOnly(2026, 3, 28);
        final after = DateOnly(2026, 3, 29);
        expect(after.differenceInDays(before), 1);
        expect(before.addDays(1), after);
      });

      test('a day either side of a fall-back is exactly one day', () {
        final before = DateOnly(2026, 10, 24);
        final after = DateOnly(2026, 10, 25);
        expect(after.differenceInDays(before), 1);
        expect(before.addDays(1), after);
      });

      test('a week spanning a transition is exactly seven days', () {
        expect(DateOnly(2026, 4).differenceInDays(DateOnly(2026, 3, 25)), 7);
        expect(
          DateOnly(2026, 10, 29).differenceInDays(DateOnly(2026, 10, 22)),
          7,
        );
      });

      test('weekIndex stays stable across a transition', () {
        // The engine computes weekIndex as differenceInDays ~/ 7. A block
        // starting before the spring-forward must not skip or repeat a week.
        final blockStart = DateOnly(2026, 3, 2);
        int weekIndex(DateOnly date) => date.differenceInDays(blockStart) ~/ 7;
        expect(weekIndex(DateOnly(2026, 3, 2)), 0);
        expect(weekIndex(DateOnly(2026, 3, 8)), 0);
        expect(weekIndex(DateOnly(2026, 3, 9)), 1);
        expect(weekIndex(DateOnly(2026, 3, 30)), 4);
        expect(weekIndex(DateOnly(2026, 4, 5)), 4);
        expect(weekIndex(DateOnly(2026, 4, 6)), 5);
      });
    });

    group('startOfWeek', () {
      test('returns the Monday on or before the date by default', () {
        // 2026-08-19 is a Wednesday.
        expect(DateOnly(2026, 8, 19).startOfWeek(), DateOnly(2026, 8, 17));
        // A Monday is its own start of week.
        expect(DateOnly(2026, 8, 17).startOfWeek(), DateOnly(2026, 8, 17));
        // A Sunday belongs to the week that began six days earlier.
        expect(DateOnly(2026, 8, 23).startOfWeek(), DateOnly(2026, 8, 17));
      });

      test('honours a Sunday-first week', () {
        expect(
          DateOnly(2026, 8, 19).startOfWeek(firstWeekday: DateTime.sunday),
          DateOnly(2026, 8, 16),
        );
        expect(
          DateOnly(2026, 8, 16).startOfWeek(firstWeekday: DateTime.sunday),
          DateOnly(2026, 8, 16),
        );
      });
    });

    group('comparison', () {
      final earlier = DateOnly(2026, 8, 19);
      final later = DateOnly(2026, 8, 20);

      test('orders by date', () {
        expect(earlier.isBefore(later), isTrue);
        expect(later.isAfter(earlier), isTrue);
        expect(earlier.isBefore(earlier), isFalse);
        expect(earlier.isAfter(earlier), isFalse);
        expect(earlier.isSameDayAs(DateOnly(2026, 8, 19)), isTrue);
        expect(earlier.isSameDayAs(later), isFalse);
      });

      test('supports the comparison operators', () {
        expect(earlier < later, isTrue);
        expect(earlier <= later, isTrue);
        expect(earlier <= earlier, isTrue);
        expect(later > earlier, isTrue);
        expect(later >= earlier, isTrue);
        expect(earlier >= earlier, isTrue);
        expect(later < earlier, isFalse);
        expect(later <= earlier, isFalse);
        expect(earlier > later, isFalse);
        expect(earlier >= later, isFalse);
      });

      test('compareTo sorts ascending', () {
        final dates = [later, earlier, DateOnly(2026)]..sort();
        expect(dates, [DateOnly(2026), earlier, later]);
        expect(earlier.compareTo(earlier), 0);
      });

      test('equal dates are equal and hash alike', () {
        expect(DateOnly(2026, 8, 19), DateOnly(2026, 8, 19));
        expect(DateOnly(2026, 8, 19).hashCode, DateOnly(2026, 8, 19).hashCode);
        expect(DateOnly(2026, 8, 19), isNot(later));
        // Deliberately comparing across types: == must reject a non-DateOnly
        // rather than throw, since it is reachable from collection lookups.
        // ignore: unrelated_type_equality_checks
        expect(DateOnly(2026, 8, 19) == '2026-08-19', isFalse);
      });

      test('works as a map key', () {
        final byDate = {DateOnly(2026, 8, 19): 'leg day'};
        expect(byDate[DateOnly(2026, 8, 19)], 'leg day');
        expect(byDate[later], isNull);
      });
    });

    group('conversion', () {
      test('toUtcDateTime is midnight UTC', () {
        final utc = DateOnly(2026, 8, 19).toUtcDateTime();
        expect(utc, DateTime.utc(2026, 8, 19));
        expect(utc.isUtc, isTrue);
        expect(utc.hour, 0);
      });

      test('toLocalDateTime is local midnight on the same calendar date', () {
        final local = DateOnly(2026, 8, 19).toLocalDateTime();
        expect(local.isUtc, isFalse);
        expect(local.year, 2026);
        expect(local.month, 8);
        expect(local.day, 19);
        expect(local.hour, 0);
      });

      test('survives a round trip through local midnight', () {
        // Includes both 2026 European DST transition days.
        for (final date in [
          DateOnly(2026, 3, 29),
          DateOnly(2026, 10, 25),
          DateOnly(2026, 8, 19),
        ]) {
          expect(DateOnly.fromDateTime(date.toLocalDateTime()), date);
        }
      });
    });
  });
}
