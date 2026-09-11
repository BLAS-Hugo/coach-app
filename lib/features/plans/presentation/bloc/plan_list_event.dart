part of 'plan_list_bloc.dart';

sealed class PlanListEvent extends Equatable {
  const PlanListEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching the plan list. Sent once, when the screen opens.
final class PlanListSubscriptionRequested extends PlanListEvent {
  const PlanListSubscriptionRequested();
}

/// Create a plan from the "+ Nouveau plan" sheet.
final class PlanListPlanCreated extends PlanListEvent {
  const PlanListPlanCreated({required this.name, required this.type});

  final String name;

  /// Fixed at creation and never editable afterwards (PRD §5.4): the type
  /// decides which editor and which runner the plan gets.
  final PlanType type;

  @override
  List<Object?> get props => [name, type];
}

/// Soft-delete a plan. Its session logs stay readable in history.
final class PlanListPlanDeleted extends PlanListEvent {
  const PlanListPlanDeleted({required this.planId});

  final String planId;

  @override
  List<Object?> get props => [planId];
}
