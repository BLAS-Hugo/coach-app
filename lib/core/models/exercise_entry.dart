import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_entry.freezed.dart';

/// One exercise within a strength session template, with its planned sets
/// hanging off it by id.
///
/// [supersetGroup] is null for a plain exercise. Entries sharing a group are
/// performed alternating (PRD §4.4); a group of one is just a normal
/// exercise, which is what keeps the runner's round-based logic uniform.
@freezed
abstract class ExerciseEntry with _$ExerciseEntry {
  const factory ExerciseEntry({
    required String id,
    required String sessionTemplateId,
    required String exerciseId,
    required int orderIndex,
    int? supersetGroup,

    /// Overrides the global default rest duration for this exercise only.
    int? restSeconds,
    String? notes,
  }) = _ExerciseEntry;
}
