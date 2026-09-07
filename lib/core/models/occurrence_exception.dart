import 'package:coach_app/core/utils/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'occurrence_exception.freezed.dart';

/// What a single-occurrence exception does.
enum OccurrenceExceptionKind {
  /// The user explicitly chose not to train that day.
  skip,

  /// The session moves to another date.
  move,
}

/// A one-off deviation affecting a single date of a training block.
///
/// Distinct from a `WeekOverride`, which changes a whole week of the
/// template. An exception is the user reacting to one day.
@freezed
abstract class OccurrenceException with _$OccurrenceException {
  const factory OccurrenceException({
    required String id,
    required String blockId,

    /// The date the occurrence was originally scheduled for.
    required DateOnly date,
    required OccurrenceExceptionKind kind,

    /// Where the occurrence moves to. Set when [kind] is
    /// [OccurrenceExceptionKind.move].
    DateOnly? targetDate,
  }) = _OccurrenceException;
}
