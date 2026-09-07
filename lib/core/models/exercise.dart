import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';

/// A named movement with a stable identity (PRD §4.5).
///
/// Deliberately minimal, and deliberately not a seeded catalogue: exercises
/// are created inline while building a session. The identity exists so that
/// per-exercise history aggregates instead of fragmenting across spelling
/// variants — which is why the repository matches on a normalised name
/// before creating a new one.
@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    String? muscleGroup,
    String? notes,
  }) = _Exercise;
}
