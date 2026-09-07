import 'package:coach_app/core/utils/date_only.dart';
import 'package:meta/meta.dart';

/// An inclusive range of calendar dates.
///
/// Inclusive on both ends because every range in this app is one the user
/// can point at — "the fortnight around today", "this training block",
/// "week 3" — and a half-open end date reads wrong in all of them.
@immutable
final class DateRange {
  const DateRange({required this.start, required this.end})
    : assert(start <= end, 'A DateRange may not end before it starts');

  /// The [days]-day range starting at [start].
  factory DateRange.days(DateOnly start, int days) {
    assert(days >= 1, 'A DateRange spans at least one day');
    return DateRange(start: start, end: start.addDays(days - 1));
  }

  /// The window the day view shows: [radius] days either side of [around].
  ///
  /// PRD §5.1 asks for ±7 days, which is the default.
  factory DateRange.around(DateOnly around, {int radius = 7}) {
    assert(radius >= 0, 'radius may not be negative');
    return DateRange(
      start: around.addDays(-radius),
      end: around.addDays(radius),
    );
  }

  final DateOnly start;
  final DateOnly end;

  /// Number of days covered, both ends included.
  int get length => end.differenceInDays(start) + 1;

  /// Every date in the range, ascending. Lazy — the engine walks this once
  /// per block and never materialises it.
  Iterable<DateOnly> get days sync* {
    for (var date = start; !date.isAfter(end); date = date.addDays(1)) {
      yield date;
    }
  }

  bool contains(DateOnly date) => !date.isBefore(start) && !date.isAfter(end);

  /// Whether this range shares at least one day with [other].
  bool overlaps(DateRange other) =>
      !start.isAfter(other.end) && !other.start.isAfter(end);

  /// The days this range and [other] have in common, or null if they are
  /// disjoint. Used to clip a block's span to the requested window.
  DateRange? intersect(DateRange other) {
    if (!overlaps(other)) return null;
    return DateRange(
      start: start.isAfter(other.start) ? start : other.start,
      end: end.isBefore(other.end) ? end : other.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start..$end';
}
