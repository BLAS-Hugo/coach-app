import 'package:freezed_annotation/freezed_annotation.dart';

part 'logged_exercise.freezed.dart';

/// One exercise as performed, inside a session log.
///
/// Part of a snapshot: it keeps its own order and superset grouping so a
/// later edit to the template cannot reorder a session that already
/// happened.
@freezed
abstract class LoggedExercise with _$LoggedExercise {
  const factory LoggedExercise({
    required String id,
    required String sessionLogId,
    required String exerciseId,
    required int orderIndex,
    int? supersetGroup,

    /// True when the user skipped this exercise but finished the session.
    @Default(false) bool skipped,
    String? notes,
  }) = _LoggedExercise;
}
