import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';

/// Everything the engine needs to compute a window of occurrences.
///
/// Assembled by the repository layer from live Drift streams and handed in
/// whole, so the engine itself stays a pure function of its input with no
/// I/O and no clock. That is what makes it testable without a database.
class SchedulingInput {
  const SchedulingInput({
    required this.plans,
    required this.today,
    this.blocksByPlan = const {},
    this.slotsByBlock = const {},
    this.overridesByBlock = const {},
    this.movesByBlock = const {},
    this.logs = const [],
  });

  final List<Plan> plans;

  /// Blocks keyed by their plan's id.
  final Map<String, List<TrainingBlock>> blocksByPlan;

  /// Weekly template slots keyed by their block's id.
  final Map<String, List<WeeklySlot>> slotsByBlock;

  /// Week overrides keyed by their block's id.
  final Map<String, List<WeekOverride>> overridesByBlock;

  /// Single-date reschedules keyed by their block's id.
  final Map<String, List<OccurrenceMove>> movesByBlock;

  /// Every log that could fall in the requested window.
  final List<SessionLog> logs;

  /// The current date, injected rather than read, so the engine never
  /// touches the wall clock.
  final DateOnly today;
}

/// Derives which sessions fall on which dates.
///
/// This is the single most important piece of logic in the app
/// (`docs/PLANNING.md` §4). It is pure: same input, same output, no I/O, no
/// `DateTime.now()`. Every date it touches is a [DateOnly], so DST cannot
/// perturb the week arithmetic.
///
/// Rest days emit nothing. A date with no occurrence from any plan is a rest
/// day, and the day view renders its empty state from the absence of cards.
abstract final class OccurrenceEngine {
  /// Computes every occurrence falling inside [range].
  ///
  /// Results are sorted by date, then by plan order within a date, so the
  /// day view can render them without re-sorting.
  static List<SessionOccurrence> computeOccurrences({
    required SchedulingInput input,
    required DateRange range,
  }) {
    final logsByKey = _indexLogs(input.logs);
    final occurrences = <SessionOccurrence>[];

    for (final plan in input.plans) {
      final blocks = input.blocksByPlan[plan.id] ?? const [];
      for (final block in blocks) {
        _collectForBlock(
          input: input,
          range: range,
          plan: plan,
          block: block,
          logsByKey: logsByKey,
          into: occurrences,
        );
      }
    }

    occurrences.sort(_byDateThenPlan);
    return occurrences;
  }

  static void _collectForBlock({
    required SchedulingInput input,
    required DateRange range,
    required Plan plan,
    required TrainingBlock block,
    required Map<String, SessionLog> logsByKey,
    required List<SessionOccurrence> into,
  }) {
    // A moved occurrence can land inside the window from a source date
    // outside it, and one scheduled inside can move out. Widen the walk by
    // the largest move distance so neither is lost.
    final moves = input.movesByBlock[block.id] ?? const [];
    final walk = _walkRange(range, block, moves);
    if (walk == null) return;

    final slots = input.slotsByBlock[block.id] ?? const [];
    if (slots.isEmpty) return;
    final slotByWeekday = {for (final slot in slots) slot.weekday: slot};

    final overrides = input.overridesByBlock[block.id] ?? const [];
    final moveByDate = {for (final move in moves) move.date: move};

    for (final date in walk.days) {
      if (!block.covers(date)) continue;

      final slot = slotByWeekday[date.weekday];
      if (slot == null) continue; // Rest day.

      final weekIndex = block.weekIndexOf(date);
      final override = _findOverride(overrides, weekIndex, date.weekday);

      var templateId = slot.sessionTemplateId;
      double? loadMultiplier;
      switch (override?.action) {
        case WeekOverrideAction.remove:
          continue; // The week override turns this day into a rest day.
        case WeekOverrideAction.replace:
          templateId = override!.replacementSessionTemplateId ?? templateId;
        case WeekOverrideAction.adjustLoad:
          loadMultiplier = override!.loadMultiplier;
        case null:
          break;
      }

      // A skip is not handled here: it is a log with status `skipped`, and
      // the status resolution below picks it up like any other log.
      final effectiveDate = moveByDate[date]?.targetDate ?? date;

      // A move can carry the occurrence out of the requested window.
      if (!range.contains(effectiveDate)) continue;

      final log = logsByKey[_logKey(plan.id, effectiveDate)];
      into.add(
        SessionOccurrence(
          planId: plan.id,
          blockId: block.id,
          type: plan.type,
          date: effectiveDate,
          sessionTemplateId: templateId,
          sessionLogId: log?.id,
          loadMultiplier: loadMultiplier,
          status: _resolveStatus(
            log: log,
            date: effectiveDate,
            today: input.today,
          ),
        ),
      );
    }
  }

  /// The span to walk for [block]: the requested [range] clipped to the
  /// block, then widened to catch occurrences that move into the window.
  static DateRange? _walkRange(
    DateRange range,
    TrainingBlock block,
    List<OccurrenceMove> moves,
  ) {
    var start = range.start;
    var end = range.end;
    for (final move in moves) {
      if (range.contains(move.targetDate)) {
        if (move.date < start) start = move.date;
        if (move.date > end) end = move.date;
      }
    }

    final widened = DateRange(start: start, end: end);
    final span = block.dateRange;
    if (span == null) {
      // Ongoing block: clip only at the start.
      return block.startDate > widened.end
          ? null
          : DateRange(
              start: widened.start > block.startDate
                  ? widened.start
                  : block.startDate,
              end: widened.end,
            );
    }
    return widened.intersect(span);
  }

  static WeekOverride? _findOverride(
    List<WeekOverride> overrides,
    int weekIndex,
    int weekday,
  ) {
    for (final override in overrides) {
      if (override.weekIndex == weekIndex && override.weekday == weekday) {
        return override;
      }
    }
    return null;
  }

  static OccurrenceStatus _resolveStatus({
    required SessionLog? log,
    required DateOnly date,
    required DateOnly today,
  }) {
    // A log outranks everything: it is what actually happened.
    if (log != null) {
      return switch (log.status) {
        SessionStatus.inProgress => OccurrenceStatus.inProgress,
        SessionStatus.completed => OccurrenceStatus.completed,
        SessionStatus.skipped => OccurrenceStatus.skipped,
      };
    }
    // `missed` is derived, never stored: a past date with nothing logged.
    return date.isBefore(today)
        ? OccurrenceStatus.missed
        : OccurrenceStatus.scheduled;
  }

  /// One log per plan per date — a plan schedules at most one session a day.
  static Map<String, SessionLog> _indexLogs(List<SessionLog> logs) => {
    for (final log in logs) _logKey(log.planId, log.date): log,
  };

  static String _logKey(String planId, DateOnly date) => '$planId@$date';

  /// Date first, then strength before endurance — the order the design's
  /// date-strip tracks use, so a day's two cards always stack the same way.
  static int _byDateThenPlan(SessionOccurrence a, SessionOccurrence b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byType = a.type.index.compareTo(b.type.index);
    return byType != 0 ? byType : a.planId.compareTo(b.planId);
  }
}
