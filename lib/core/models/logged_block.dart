import 'package:coach_app/core/models/endurance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'logged_block.freezed.dart';

/// One endurance block as performed.
///
/// [roundIndex] flattens repeat groups: round 2 of a `6 × 400 m` group is
/// its own row, so the runner advances through a plain list.
///
/// [intensityLabel] is denormalised text on purpose — if the user deletes
/// the "Z4" label two years from now, old logs must still read "Z4".
@freezed
abstract class LoggedBlock with _$LoggedBlock {
  const factory LoggedBlock({
    required String id,
    required String sessionLogId,
    required int orderIndex,
    required int roundIndex,
    required EnduranceBlockRole role,
    required EnduranceMeasure measure,
    required int targetValue,
    String? intensityLabel,
    int? actualDurationSeconds,
    int? actualDistanceMeters,
    @Default(false) bool completed,
  }) = _LoggedBlock;
}
