import 'package:coach_app/core/models/plan.dart';
import 'package:coach_app/core/models/session_template_summary.dart';
import 'package:coach_app/core/models/training_block.dart';
import 'package:coach_app/core/models/weekly_slot.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_template.freezed.dart';

/// One training block's weekly template as the editor reads it (design
/// screen 4b).
///
/// A projection, like `PlanSummary`: the plan, its blocks, the block's seven
/// weekdays and the plan's templates, gathered so the screen renders from
/// one value instead of joining four streams. It carries [today] because
/// everything the screen decides — whether the block can still be edited,
/// where "after this week" ends, how short it may be made — is a function
/// of the day, and deciding it against one captured day keeps those answers
/// consistent with each other.
@freezed
abstract class WeekTemplate with _$WeekTemplate {
  const factory WeekTemplate({
    required Plan plan,
    required DateOnly today,

    /// Every live block of the plan, chronological.
    @Default([]) List<TrainingBlock> blocks,

    /// The block being edited, or null while the plan has none.
    TrainingBlock? block,

    /// [block]'s weekly template, at most one slot per weekday.
    @Default([]) List<WeeklySlot> slots,

    /// Every live template of the plan, by name — the choices a weekday can
    /// be given, including those no weekday uses yet.
    @Default([]) List<SessionTemplateSummary> templates,
  }) = _WeekTemplate;

  const WeekTemplate._();

  /// 1-based position of [block] among its siblings — the "bloc 2" of the
  /// header.
  int? get blockOrdinal {
    final current = block;
    if (current == null) return null;
    final index = blocks.indexWhere((candidate) => candidate.id == current.id);
    return index == -1 ? null : index + 1;
  }

  /// The slot on ISO [weekday], or null for a rest day.
  WeeklySlot? slotOn(int weekday) {
    for (final slot in slots) {
      if (slot.weekday == weekday) return slot;
    }
    return null;
  }

  /// The template with this id, or null if it is gone.
  SessionTemplateSummary? templateById(String id) {
    for (final summary in templates) {
      if (summary.template.id == id) return summary;
    }
    return null;
  }

  /// Where [block] sits relative to [today], or null without a block.
  TrainingBlockStatus? get blockStatus => block?.statusOn(today);

  /// Whether the weekly template may still change.
  ///
  /// A finished block has no future occurrence left to change, so an edit
  /// could only alter how past days it never logged are drawn (PRD §5.4) —
  /// all cost, no benefit. It is shown, not edited.
  bool get isEditable =>
      block != null && blockStatus != TrainingBlockStatus.finished;

  /// The end date "Arrêter le bloc après cette semaine" would set: the last
  /// day of the block week today falls in (PRD §3).
  ///
  /// Null when there is nothing to stop — no block, a block not running
  /// today, or one already ending by then.
  DateOnly? get stopDate {
    final current = block;
    if (current == null || blockStatus != TrainingBlockStatus.active) {
      return null;
    }
    final weekEnd = current.startDate.addDays(
      (current.weekIndexOf(today) + 1) * 7 - 1,
    );
    final end = current.endDate;
    return end != null && !end.isAfter(weekEnd) ? null : weekEnd;
  }

  /// The shortest duration [block] may be given.
  ///
  /// A running block cannot be shortened into the past: the week in
  /// progress is the earliest it may end, which is what stopping does.
  int get minDurationWeeks {
    final current = block;
    if (current == null || blockStatus != TrainingBlockStatus.active) return 1;
    return current.weekIndexOf(today) + 1;
  }

  /// Whether "Dupliquer la semaine" has somewhere to put a copy.
  ///
  /// The copy starts the day after [block] ends, so an ongoing block — one
  /// that never ends — has no such day.
  bool get canDuplicate => block?.endDate != null;
}
