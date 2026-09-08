import 'package:coach_app/core/models/set_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'planned_set.freezed.dart';

/// One planned work set. [kind] decides which of the value fields carry
/// meaning; the others are null (PRD §4.2).
///
/// [weight] is kilograms, always — the kg/lb preference is applied when the
/// value is rendered, never when it is stored.
@freezed
abstract class PlannedSet with _$PlannedSet {
  const factory PlannedSet({
    required String id,
    required String exerciseEntryId,
    required int orderIndex,
    required SetKind kind,

    /// Kilograms.
    double? weight,
    int? reps,
    int? durationSeconds,

    /// RPE or RIR; which scale is shown is a global setting.
    double? targetIntensity,
  }) = _PlannedSet;
}
