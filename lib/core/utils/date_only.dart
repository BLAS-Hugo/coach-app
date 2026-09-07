import 'package:meta/meta.dart';

/// A calendar date with no time component and no time zone.
///
/// The occurrence engine's correctness rests on this type. `DateTime`
/// arithmetic lies across DST boundaries — adding `Duration(days: 1)` to a
/// local midnight lands on 23:00 or 01:00, and `difference().inDays` between
/// two local midnights one day apart returns 0 when the clock sprang
/// forward. Neither is possible here: a [DateOnly] is stored as a count of
/// days, so every operation is integer arithmetic on that count.
///
/// This is also the storage format — `docs/PLANNING.md` §9 calls for
/// UTC-midnight epoch days, which is exactly [epochDay].
@immutable
final class DateOnly implements Comparable<DateOnly> {
  /// The date [year]-[month]-[day].
  ///
  /// Out-of-range values normalise the way `DateTime` does, so
  /// `DateOnly(2026, 1, 32)` is 1 February 2026 and `DateOnly(2026, 13, 1)`
  /// is 1 January 2027. [addDays] relies on this.
  factory DateOnly(int year, [int month = 1, int day = 1]) =>
      DateOnly._fromUtc(DateTime.utc(year, month, day));

  /// Discards the time component of [dateTime], keeping its calendar date in
  /// whatever zone it is already expressed in.
  ///
  /// This is the only sanctioned boundary between `DateTime` and the
  /// scheduling code: convert once, on the way in.
  factory DateOnly.fromDateTime(DateTime dateTime) =>
      DateOnly(dateTime.year, dateTime.month, dateTime.day);

  /// The current date in the device's local zone.
  ///
  /// [clock] exists so tests never depend on the wall clock; production code
  /// omits it.
  factory DateOnly.today({DateTime Function()? clock}) =>
      DateOnly.fromDateTime((clock ?? DateTime.now)());

  /// Parses an ISO-8601 calendar date, `YYYY-MM-DD`.
  ///
  /// Throws [FormatException] on anything else, including a date that
  /// carries a time.
  factory DateOnly.parse(String iso) {
    final match = _isoPattern.firstMatch(iso);
    if (match == null) {
      throw FormatException('Not an ISO-8601 calendar date', iso);
    }
    return DateOnly(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  const DateOnly._(this.epochDay);

  factory DateOnly._fromUtc(DateTime utc) {
    // Floor division, so dates before 1970 round the same direction as
    // dates after it. Truncating division would fold 1969-12-31 onto day 0.
    const millisecondsPerDay = Duration.millisecondsPerDay;
    final ms = utc.millisecondsSinceEpoch;
    final days = ms >= 0
        ? ms ~/ millisecondsPerDay
        : -(((-ms) + millisecondsPerDay - 1) ~/ millisecondsPerDay);
    return DateOnly._(days);
  }

  static final RegExp _isoPattern = RegExp(r'^(-?\d{4,6})-(\d{2})-(\d{2})$');

  /// Days since 1970-01-01. Negative before it.
  final int epochDay;

  DateTime get _utc => DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );

  int get year => _utc.year;

  int get month => _utc.month;

  int get day => _utc.day;

  /// ISO weekday: 1 is Monday, 7 is Sunday. Matches [DateTime.weekday] and
  /// the `weekday` column of `weekly_slots`.
  int get weekday => _utc.weekday;

  /// This date at midnight in the device's local zone.
  ///
  /// For display and for handing to `intl`. Never feed the result back into
  /// date arithmetic.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  /// This date at midnight UTC. The value written to the database.
  DateTime toUtcDateTime() => _utc;

  DateOnly addDays(int days) => DateOnly._(epochDay + days);

  DateOnly addWeeks(int weeks) => addDays(weeks * 7);

  /// Days from [other] to this date. Positive when this is the later one.
  ///
  /// Exact at every DST boundary, which `DateTime.difference().inDays` is
  /// not.
  int differenceInDays(DateOnly other) => epochDay - other.epochDay;

  /// The most recent [weekday] on or before this date.
  ///
  /// Used to align a week index onto the user's chosen first day of week.
  DateOnly startOfWeek({int firstWeekday = DateTime.monday}) =>
      addDays(-((weekday - firstWeekday) % 7));

  bool isBefore(DateOnly other) => epochDay < other.epochDay;

  bool isAfter(DateOnly other) => epochDay > other.epochDay;

  bool isSameDayAs(DateOnly other) => epochDay == other.epochDay;

  @override
  int compareTo(DateOnly other) => epochDay.compareTo(other.epochDay);

  bool operator <(DateOnly other) => epochDay < other.epochDay;

  bool operator <=(DateOnly other) => epochDay <= other.epochDay;

  bool operator >(DateOnly other) => epochDay > other.epochDay;

  bool operator >=(DateOnly other) => epochDay >= other.epochDay;

  @override
  bool operator ==(Object other) =>
      other is DateOnly && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  /// ISO-8601 `YYYY-MM-DD`. Round-trips through [DateOnly.parse].
  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
