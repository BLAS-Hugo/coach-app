import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_override.freezed.dart';

/// What a week override does to the slot it targets.
enum WeekOverrideAction {
  /// Swap in a different session template for that week only.
  replace,

  /// Drop the session for that week, turning it into a rest day.
  remove,

  /// Keep the session but scale its working loads, for a deload.
  adjustLoad,
}

/// A per-week deviation from a training block's weekly template (PRD §3).
///
/// [weekIndex] is 0-based from the block's start date, counted the way
/// `TrainingBlock.weekIndexOf` counts, so week 0 may be a partial week.
@freezed
abstract class WeekOverride with _$WeekOverride {
  const factory WeekOverride({
    required String id,
    required String blockId,
    required int weekIndex,

    /// ISO weekday, 1 (Monday) to 7 (Sunday).
    required int weekday,
    required WeekOverrideAction action,

    /// Set when [action] is [WeekOverrideAction.replace].
    String? replacementSessionTemplateId,

    /// Set when [action] is [WeekOverrideAction.adjustLoad]. `0.8` is the
    /// −20 % deload of PRD §6.3.
    double? loadMultiplier,
  }) = _WeekOverride;
}
