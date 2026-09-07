import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_block.freezed.dart';

/// Where a training block sits relative to a given day.
enum TrainingBlockStatus {
  /// Starts in the future.
  upcoming,

  /// Covers the day.
  active,

  /// Ended before the day.
  finished,
}

/// One mesocycle within a plan: a start date, a duration in weeks, and
/// exactly one weekly template that repeats for that duration (PRD §3).
///
/// Not to be confused with an *endurance block*, which is a segment of a
/// single endurance session.
///
/// The end date is derived rather than stored. [explicitEndDate] is set only
/// when the user stops a block early ("Arrêter le bloc après cette
/// semaine"); otherwise the end follows from [startDate] and
/// [durationWeeks]. A block with neither is ongoing and schedules sessions
/// indefinitely. Storing a status column was considered and rejected — it is
/// a pure function of the dates and the current day, so a stored copy goes
/// stale the moment the clock passes midnight.
@freezed
abstract class TrainingBlock with _$TrainingBlock {
  const factory TrainingBlock({
    required String id,
    required String planId,
    required String name,
    required int orderIndex,
    required DateOnly startDate,
    int? durationWeeks,
    DateOnly? explicitEndDate,
    String? notes,
  }) = _TrainingBlock;

  const TrainingBlock._();

  /// The last day this block schedules a session, or null if it is ongoing.
  ///
  /// An explicit end always wins, including when it falls before the end the
  /// duration implies — that is what stopping a block early means.
  DateOnly? get endDate {
    final explicit = explicitEndDate;
    if (explicit != null) return explicit;
    final weeks = durationWeeks;
    if (weeks == null) return null;
    return startDate.addDays(weeks * 7 - 1);
  }

  /// True while the block has no end date and so runs indefinitely.
  bool get isOngoing => endDate == null;

  /// The span this block covers, or null if it is ongoing and therefore
  /// unbounded.
  DateRange? get dateRange {
    final end = endDate;
    return end == null ? null : DateRange(start: startDate, end: end);
  }

  /// Whether this block schedules anything on [date].
  bool covers(DateOnly date) {
    if (date.isBefore(startDate)) return false;
    final end = endDate;
    return end == null || !date.isAfter(end);
  }

  /// The 0-based week of this block that [date] falls in.
  ///
  /// Week 0 is the partial week beginning on [startDate]: a block starting
  /// on a Thursday has a week 0 of Thursday to the following Wednesday. This
  /// is what a week override's `weekIndex` counts, and it must mean the same
  /// thing to the user and to the engine (`docs/PLANNING.md` §4).
  ///
  /// Returns a negative index for a date before the block starts.
  int weekIndexOf(DateOnly date) {
    final days = date.differenceInDays(startDate);
    // Floor rather than truncate, so dates before the start count backwards
    // instead of folding onto week 0.
    return days >= 0 ? days ~/ 7 : -(((-days) + 6) ~/ 7);
  }

  /// How many whole or partial weeks this block spans, or null if ongoing.
  int? get weekCount {
    final end = endDate;
    return end == null ? null : weekIndexOf(end) + 1;
  }

  /// Where this block sits relative to [today].
  TrainingBlockStatus statusOn(DateOnly today) {
    if (today.isBefore(startDate)) return TrainingBlockStatus.upcoming;
    return covers(today)
        ? TrainingBlockStatus.active
        : TrainingBlockStatus.finished;
  }

  /// Whether this block shares any day with [other].
  ///
  /// Blocks in one plan may not overlap (PRD §4.1); the plan repository
  /// enforces that on write using this.
  bool overlaps(TrainingBlock other) {
    final end = endDate;
    final otherEnd = other.endDate;
    if (end != null && other.startDate.isAfter(end)) return false;
    if (otherEnd != null && startDate.isAfter(otherEnd)) return false;
    return true;
  }
}
