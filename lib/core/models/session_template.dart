import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_template.freezed.dart';

/// A named workout belonging to a plan (PRD §3).
///
/// Owned by the plan rather than by a block, so duplicating a week into the
/// next block reuses the same templates instead of copying them.
///
/// The content — exercise entries and planned sets for strength, endurance
/// blocks and repeat groups for endurance — hangs off this by id. The
/// occurrence engine never reads it: scheduling only needs to know *which*
/// template lands on a date, not what is in it.
@freezed
abstract class SessionTemplate with _$SessionTemplate {
  const factory SessionTemplate({
    required String id,
    required String planId,
    required String name,
    String? notes,
  }) = _SessionTemplate;
}
