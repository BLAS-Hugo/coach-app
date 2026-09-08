import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateRange', () {
    final august = DateRange(
      start: DateOnly(2026, 8, 10),
      end: DateOnly(2026, 8, 16),
    );

    test('is inclusive at both ends', () {
      expect(august.length, 7);
      expect(august.contains(DateOnly(2026, 8, 10)), isTrue);
      expect(august.contains(DateOnly(2026, 8, 16)), isTrue);
      expect(august.contains(DateOnly(2026, 8, 9)), isFalse);
      expect(august.contains(DateOnly(2026, 8, 17)), isFalse);
    });

    test('a single-day range has length one', () {
      final oneDay = DateRange(
        start: DateOnly(2026, 8, 10),
        end: DateOnly(2026, 8, 10),
      );
      expect(oneDay.length, 1);
      expect(oneDay.days, [DateOnly(2026, 8, 10)]);
    });

    test('rejects an end before the start', () {
      expect(
        () => DateRange(start: DateOnly(2026, 8, 10), end: DateOnly(2026, 8)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('days yields every date once, ascending', () {
      expect(august.days.length, august.length);
      expect(august.days.first, august.start);
      expect(august.days.last, august.end);
      expect(august.days.toSet().length, august.length);
      final ordered = august.days.toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].differenceInDays(ordered[i - 1]), 1);
      }
    });

    test('days spans a DST transition without dropping or repeating a day', () {
      final acrossSpringForward = DateRange(
        start: DateOnly(2026, 3, 27),
        end: DateOnly(2026, 3, 31),
      );
      expect(acrossSpringForward.days.toList(), [
        DateOnly(2026, 3, 27),
        DateOnly(2026, 3, 28),
        DateOnly(2026, 3, 29),
        DateOnly(2026, 3, 30),
        DateOnly(2026, 3, 31),
      ]);
    });

    group('factories', () {
      test('days builds an n-day range from the start', () {
        final range = DateRange.days(DateOnly(2026, 8, 10), 7);
        expect(range, august);
        expect(DateRange.days(DateOnly(2026, 8, 10), 1).length, 1);
      });

      test('days rejects a non-positive length', () {
        expect(
          () => DateRange.days(DateOnly(2026, 8, 10), 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('around builds the PRD §5.1 fortnight by default', () {
        final range = DateRange.around(DateOnly(2026, 8, 19));
        expect(range.start, DateOnly(2026, 8, 12));
        expect(range.end, DateOnly(2026, 8, 26));
        expect(range.length, 15);
        expect(range.contains(DateOnly(2026, 8, 19)), isTrue);
      });

      test('around honours a custom radius, including zero', () {
        expect(DateRange.around(DateOnly(2026, 8, 19), radius: 0).length, 1);
        expect(DateRange.around(DateOnly(2026, 8, 19), radius: 3).length, 7);
      });

      test('around rejects a negative radius', () {
        expect(
          () => DateRange.around(DateOnly(2026, 8, 19), radius: -1),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('overlaps', () {
      test('is true when the ranges share any day, including one', () {
        expect(
          august.overlaps(
            DateRange(start: DateOnly(2026, 8, 16), end: DateOnly(2026, 8, 20)),
          ),
          isTrue,
        );
        expect(
          august.overlaps(
            DateRange(start: DateOnly(2026, 8), end: DateOnly(2026, 8, 10)),
          ),
          isTrue,
        );
        expect(august.overlaps(august), isTrue);
      });

      test('is false for adjacent but disjoint ranges', () {
        expect(
          august.overlaps(
            DateRange(start: DateOnly(2026, 8, 17), end: DateOnly(2026, 8, 20)),
          ),
          isFalse,
        );
        expect(
          august.overlaps(
            DateRange(start: DateOnly(2026, 8), end: DateOnly(2026, 8, 9)),
          ),
          isFalse,
        );
      });

      test('is symmetric', () {
        final other = DateRange(
          start: DateOnly(2026, 8, 14),
          end: DateOnly(2026, 9),
        );
        expect(august.overlaps(other), other.overlaps(august));
      });
    });

    group('intersect', () {
      test('clips to the shared days', () {
        final clipped = august.intersect(
          DateRange(start: DateOnly(2026, 8, 14), end: DateOnly(2026, 8, 20)),
        );
        expect(clipped?.start, DateOnly(2026, 8, 14));
        expect(clipped?.end, DateOnly(2026, 8, 16));
      });

      test('returns the inner range when one contains the other', () {
        final inner = DateRange(
          start: DateOnly(2026, 8, 12),
          end: DateOnly(2026, 8, 13),
        );
        expect(august.intersect(inner), inner);
        expect(inner.intersect(august), inner);
      });

      test('returns null when the ranges are disjoint', () {
        expect(
          august.intersect(
            DateRange(start: DateOnly(2026, 9), end: DateOnly(2026, 9, 5)),
          ),
          isNull,
        );
      });
    });

    group('value semantics', () {
      test('equal ranges are equal and hash alike', () {
        final same = DateRange(
          start: DateOnly(2026, 8, 10),
          end: DateOnly(2026, 8, 16),
        );
        expect(august, same);
        expect(august.hashCode, same.hashCode);
        expect(
          august,
          isNot(
            DateRange(start: DateOnly(2026, 8, 10), end: DateOnly(2026, 8, 17)),
          ),
        );
      });

      test('reads as an ISO span', () {
        expect(august.toString(), '2026-08-10..2026-08-16');
      });
    });
  });
}
