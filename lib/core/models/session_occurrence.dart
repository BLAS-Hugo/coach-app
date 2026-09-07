import 'package:coach_app/core/models/plan.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_occurrence.freezed.dart';

/// The state of one occurrence as the day view renders it.
///
/// Maps onto the five card states of design screen 1a.
enum OccurrenceStatus {
  /// Planned, not yet started, not yet past. Outlined, never filled.
  scheduled,

  /// Started and unfinished. The only filled container in the app.
  inProgress,

  /// Finished. Always shown with a `✓`.
  completed,

  /// The user explicitly chose to skip it.
  skipped,

  /// Its date has passed with nothing logged. Derived, never stored, and
  /// never red.
  missed,
}

/// A concrete instance of a session template on a concrete date.
///
/// Computed by the occurrence engine, never stored — until the user starts
/// it, at which point a `SessionLog` materialises and [sessionLogId] points
/// at it. Everything here is derived from a plan, its block, that block's
/// weekly template, and any override or exception that applies.
@freezed
abstract class SessionOccurrence with _$SessionOccurrence {
  const factory SessionOccurrence({
    required String planId,
    required String blockId,
    required PlanType type,
    required DateOnly date,
    required OccurrenceStatus status,

    /// Null only for a rest day the engine chose to emit explicitly; a
    /// normal rest day emits nothing at all.
    String? sessionTemplateId,

    /// Set once the occurrence has been materialised into a log.
    String? sessionLogId,

    /// Carried from a `adjustLoad` week override, e.g. `0.8` for a −20 %
    /// deload. Null means loads are as planned.
    double? loadMultiplier,
  }) = _SessionOccurrence;

  const SessionOccurrence._();

  /// Whether a log exists for this occurrence.
  bool get isMaterialised => sessionLogId != null;

  /// Whether the runner can be opened on it.
  bool get isStartable =>
      status == OccurrenceStatus.scheduled ||
      status == OccurrenceStatus.inProgress ||
      status == OccurrenceStatus.missed;
}
