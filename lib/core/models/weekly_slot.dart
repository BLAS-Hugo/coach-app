import 'package:freezed_annotation/freezed_annotation.dart';

part 'weekly_slot.freezed.dart';

/// One weekday of a training block's weekly template.
///
/// A block has at most one slot per weekday; a weekday with no slot is a
/// rest day and produces no occurrence.
@freezed
abstract class WeeklySlot with _$WeeklySlot {
  const factory WeeklySlot({
    required String id,
    required String blockId,

    /// ISO weekday, 1 (Monday) to 7 (Sunday), matching [DateTime.weekday].
    required int weekday,
    required String sessionTemplateId,
  }) = _WeeklySlot;
}
