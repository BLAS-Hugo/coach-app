part of 'week_template_bloc.dart';

enum WeekTemplateStatus {
  initial,
  loading,
  success,

  /// The plan is gone — deleted elsewhere, or never existed.
  notFound,
  failure,
}

/// Why the last edit did not land.
enum WeekTemplateError {
  /// The block would overlap a sibling in the same plan.
  blockOverlap,

  /// The block would overlap a plan of the same type (PRD §4.1).
  planConflict,

  /// Anything else.
  unknown,
}

/// What it takes to put back the state an edit replaced.
///
/// Held as data rather than as a closure so the state stays comparable.
sealed class WeekTemplateUndo extends Equatable {
  const WeekTemplateUndo();
}

/// The whole week of [blockId] as it was before a slot edit.
final class WeekTemplateSlotsUndo extends WeekTemplateUndo {
  const WeekTemplateSlotsUndo({required this.blockId, required this.slots});

  final String blockId;
  final List<WeeklySlot> slots;

  @override
  List<Object?> get props => [blockId, slots];
}

/// The block as it was before its dates changed.
final class WeekTemplateBlockUndo extends WeekTemplateUndo {
  const WeekTemplateBlockUndo({required this.block});

  final TrainingBlock block;

  @override
  List<Object?> get props => [block];
}

class WeekTemplateState extends Equatable {
  const WeekTemplateState({
    this.status = WeekTemplateStatus.initial,
    this.week,
    this.undo = const [],
    this.error,
    this.duplicatedBlockId,
  });

  final WeekTemplateStatus status;
  final WeekTemplate? week;

  /// Undoable edits, oldest first.
  final List<WeekTemplateUndo> undo;

  /// Set by an edit that failed; cleared by the next edit.
  final WeekTemplateError? error;

  /// Set once "Dupliquer la semaine" has made a block, so the view can open
  /// it.
  final String? duplicatedBlockId;

  bool get canUndo => undo.isNotEmpty;

  WeekTemplateState copyWith({
    WeekTemplateStatus? status,
    WeekTemplate? week,
    List<WeekTemplateUndo>? undo,
    WeekTemplateError? Function()? error,
    String? duplicatedBlockId,
  }) {
    return WeekTemplateState(
      status: status ?? this.status,
      week: week ?? this.week,
      undo: undo ?? this.undo,
      error: error != null ? error() : this.error,
      duplicatedBlockId: duplicatedBlockId ?? this.duplicatedBlockId,
    );
  }

  @override
  List<Object?> get props => [status, week, undo, error, duplicatedBlockId];
}
