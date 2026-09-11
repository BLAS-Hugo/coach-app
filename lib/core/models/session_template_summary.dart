import 'package:coach_app/core/models/session_template.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_template_summary.freezed.dart';

/// A session template with the size of its content, as a one-line meta
/// reads it: "6 exercices · 24 séries" for strength, "7 blocs" for
/// endurance.
///
/// Counted rather than loaded: the weekly template shows how big a session
/// is, never what is in it.
@freezed
abstract class SessionTemplateSummary with _$SessionTemplateSummary {
  const factory SessionTemplateSummary({
    required SessionTemplate template,

    /// Live exercise entries, strength only.
    @Default(0) int exerciseCount,

    /// Live planned sets across those entries, strength only.
    @Default(0) int setCount,

    /// Live endurance blocks, endurance only. A repeat group counts its
    /// blocks once, not once per round.
    @Default(0) int enduranceBlockCount,
  }) = _SessionTemplateSummary;

  const SessionTemplateSummary._();

  /// True while the template holds no content of either kind.
  bool get isEmpty =>
      exerciseCount == 0 && setCount == 0 && enduranceBlockCount == 0;
}
