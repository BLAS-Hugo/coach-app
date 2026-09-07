import 'package:coach_app/core/models/endurance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'endurance_block.freezed.dart';

/// One segment of an endurance session template.
///
/// Not to be confused with a `TrainingBlock`, which is a mesocycle.
///
/// [targetValue] is seconds when [measure] is
/// [EnduranceMeasure.duration] and metres when it is
/// [EnduranceMeasure.distance] — there is no third unit, and distances are
/// stored in metres regardless of the km/mi display preference.
@freezed
abstract class EnduranceBlock with _$EnduranceBlock {
  const factory EnduranceBlock({
    required String id,
    required String sessionTemplateId,
    required int orderIndex,
    required EnduranceBlockRole role,
    required EnduranceMeasure measure,
    required int targetValue,

    /// Set when this block belongs to a repeat group.
    String? repeatGroupId,
    String? intensityLabelId,
    String? notes,
  }) = _EnduranceBlock;
}
