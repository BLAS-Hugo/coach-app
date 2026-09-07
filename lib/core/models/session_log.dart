import 'package:coach_app/core/utils/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_log.freezed.dart';

/// The lifecycle of a materialised session.
enum SessionStatus {
  /// Started and not yet finished. Survives process death (PRD N3).
  inProgress,

  /// Finished and written.
  completed,

  /// Started and abandoned, or skipped outright by the user.
  skipped,
}

/// The persisted record created when the user starts an occurrence.
///
/// A log is a **snapshot**: `plannedSnapshot` freezes what was planned at the
/// moment it was started, and no later edit to the plan touches it. That is
/// what lets a block be edited mid-flight without rewriting history
/// (PRD G4), and it is the source of the `PRÉVU` column on design screen 2c.
///
/// [sessionTemplateId] and [blockId] are deliberately nullable soft
/// references: both survive their target being soft-deleted, because a log
/// must stay readable in history forever.
@freezed
abstract class SessionLog with _$SessionLog {
  const factory SessionLog({
    required String id,
    required String planId,
    required DateOnly date,
    required SessionStatus status,
    required DateTime startedAt,
    String? blockId,
    String? sessionTemplateId,
    DateTime? completedAt,
    int? totalDurationSeconds,
    String? notes,

    /// The planned content at start time, as JSON. Redundant with the
    /// relational `logged_*` rows on purpose: those are what history
    /// queries read, this is the escape hatch for rendering a historical
    /// session exactly as it was structured, including the superset and
    /// repeat grouping the relational tables flatten.
    String? plannedSnapshot,
  }) = _SessionLog;
}
