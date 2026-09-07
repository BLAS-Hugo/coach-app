import 'package:coach_app/core/models/set_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'logged_set.freezed.dart';

/// One set as performed, carrying both what was planned and what happened.
///
/// The planned values are copied in rather than joined to the planned set
/// they came from, because that row may be edited or soft-deleted later.
/// This is what makes the `PRÉVU` / `RÉALISÉ` comparison stable forever.
@freezed
abstract class LoggedSet with _$LoggedSet {
  const factory LoggedSet({
    required String id,
    required String loggedExerciseId,
    required int orderIndex,
    required SetKind kind,
    double? plannedWeight,
    int? plannedReps,
    int? plannedDurationSeconds,
    double? plannedIntensity,
    double? actualWeight,
    int? actualReps,
    int? actualDurationSeconds,
    double? actualIntensity,
    @Default(false) bool completed,
  }) = _LoggedSet;
}
