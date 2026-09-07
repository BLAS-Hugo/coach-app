import 'package:coach_app/core/utils/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'occurrence_move.freezed.dart';

/// A single occurrence rescheduled to another date.
///
/// Distinct from a `WeekOverride`, which changes a whole week of the
/// template. A move is the user reacting to one day.
///
/// There is deliberately no "skip" variant here. A skip is a
/// `SessionLog` with status `skipped`, because skipping freezes a snapshot
/// exactly as starting does (PRD §5.2) — and one representation means the
/// two paths can never disagree.
@freezed
abstract class OccurrenceMove with _$OccurrenceMove {
  const factory OccurrenceMove({
    required String id,
    required String blockId,

    /// The date the occurrence was originally scheduled for.
    required DateOnly date,

    /// Where it moves to.
    required DateOnly targetDate,
  }) = _OccurrenceMove;
}
