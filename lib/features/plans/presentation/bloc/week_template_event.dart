part of 'week_template_bloc.dart';

sealed class WeekTemplateEvent extends Equatable {
  const WeekTemplateEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching the week. Sent once, when the screen opens.
final class WeekTemplateSubscriptionRequested extends WeekTemplateEvent {
  const WeekTemplateSubscriptionRequested();
}

/// Every event that writes. They share one handler so they run strictly one
/// after another — see `WeekTemplateBloc`.
sealed class WeekTemplateEdit extends WeekTemplateEvent {
  const WeekTemplateEdit();
}

/// Put an existing session template on a weekday, replacing whatever was
/// there.
final class WeekTemplateSessionAssigned extends WeekTemplateEdit {
  const WeekTemplateSessionAssigned({
    required this.weekday,
    required this.templateId,
  });

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  final int weekday;
  final String templateId;

  @override
  List<Object?> get props => [weekday, templateId];
}

/// Create a session template named [name] and put it on a weekday.
final class WeekTemplateSessionCreated extends WeekTemplateEdit {
  const WeekTemplateSessionCreated({required this.weekday, required this.name});

  final int weekday;
  final String name;

  @override
  List<Object?> get props => [weekday, name];
}

/// Make a weekday a rest day. The template stays in the plan.
final class WeekTemplateDayCleared extends WeekTemplateEdit {
  const WeekTemplateDayCleared({required this.weekday});

  final int weekday;

  @override
  List<Object?> get props => [weekday];
}

/// Move the session on [from] to [to]. A session already on [to] takes its
/// place on [from], so dropping one day on another swaps them.
final class WeekTemplateSessionMoved extends WeekTemplateEdit {
  const WeekTemplateSessionMoved({required this.from, required this.to});

  final int from;
  final int to;

  @override
  List<Object?> get props => [from, to];
}

/// Give the block a new length in weeks.
final class WeekTemplateDurationChanged extends WeekTemplateEdit {
  const WeekTemplateDurationChanged({required this.weeks});

  final int weeks;

  @override
  List<Object?> get props => [weeks];
}

/// "Arrêter le bloc après cette semaine".
final class WeekTemplateBlockStopped extends WeekTemplateEdit {
  const WeekTemplateBlockStopped();
}

/// Create the plan's first block.
final class WeekTemplateBlockCreated extends WeekTemplateEdit {
  const WeekTemplateBlockCreated({
    required this.name,
    required this.startDate,
    required this.durationWeeks,
  });

  final String name;
  final DateOnly startDate;
  final int durationWeeks;

  @override
  List<Object?> get props => [name, startDate, durationWeeks];
}

/// "Dupliquer la semaine": start the next block from this one's week.
final class WeekTemplateWeekDuplicated extends WeekTemplateEdit {
  const WeekTemplateWeekDuplicated({required this.name});

  /// The new block's name. Chosen by the view, which is where the French
  /// lives.
  final String name;

  @override
  List<Object?> get props => [name];
}

/// "Annuler" in the header: take back the last undoable edit.
final class WeekTemplateUndoRequested extends WeekTemplateEdit {
  const WeekTemplateUndoRequested();
}
