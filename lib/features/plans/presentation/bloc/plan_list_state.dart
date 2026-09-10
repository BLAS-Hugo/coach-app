part of 'plan_list_bloc.dart';

enum PlanListStatus { initial, loading, success, failure }

/// One state class rather than a union: every status renders the same
/// screen with the same list, so a sealed hierarchy would only make the view
/// re-read `summaries` out of four places.
class PlanListState extends Equatable {
  const PlanListState({
    this.status = PlanListStatus.initial,
    this.summaries = const [],
  });

  final PlanListStatus status;

  /// Ordered by plan name, as the repository returns them.
  final List<PlanSummary> summaries;

  /// True once the list has loaded and holds nothing — the "no plan yet"
  /// state that leads into plan creation (PRD §5.1).
  bool get isEmpty => status == PlanListStatus.success && summaries.isEmpty;

  PlanListState copyWith({
    PlanListStatus? status,
    List<PlanSummary>? summaries,
  }) {
    return PlanListState(
      status: status ?? this.status,
      summaries: summaries ?? this.summaries,
    );
  }

  @override
  List<Object?> get props => [status, summaries];
}
