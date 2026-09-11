import 'package:coach_app/core/models/plan.dart';
import 'package:coach_app/core/models/training_block.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_summary.freezed.dart';

/// One plan as the plan list reads it (design screen 4a).
///
/// A projection, not a table: everything here is derived from the plan, its
/// blocks and the block's weekly template, and it exists so the list can
/// render a card without a bloc reaching for three streams and joining them
/// itself.
///
/// A plan is **active** when one of its blocks covers today (PRD §4.1).
/// Blocks in a plan may not overlap, so at most one can qualify.
@freezed
abstract class PlanSummary with _$PlanSummary {
  const factory PlanSummary({
    required Plan plan,

    /// Every live block of the plan, however far in the past.
    required int blockCount,

    /// The block covering today, or null when nothing is running.
    TrainingBlock? currentBlock,

    /// 1-based position of [currentBlock] among its siblings, chronological
    /// — the "bloc 2" of the card.
    int? currentBlockOrdinal,

    /// 0-based week of [currentBlock] that today falls in. The card shows it
    /// 1-based: week index 2 reads "semaine 3".
    int? weekIndex,

    /// Total weeks [currentBlock] spans, or null while it is ongoing.
    int? weekCount,

    /// Sessions the current block's weekly template schedules per week.
    @Default(0) int sessionsPerWeek,
  }) = _PlanSummary;

  const PlanSummary._();

  bool get isActive => currentBlock != null;
}
