import 'package:bloc/bloc.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:equatable/equatable.dart';

part 'plan_list_event.dart';
part 'plan_list_state.dart';

/// The plan list of design screen 4a.
///
/// Holds no derived state of its own: the card's "bloc 2 · semaine 3 / 5"
/// readout is computed in the repository, so this bloc only forwards what it
/// is given and turns three user actions into repository calls.
class PlanListBloc extends Bloc<PlanListEvent, PlanListState> {
  PlanListBloc(this._plans) : super(const PlanListState()) {
    on<PlanListSubscriptionRequested>(_onSubscriptionRequested);
    on<PlanListPlanCreated>(_onPlanCreated);
    on<PlanListPlanDeleted>(_onPlanDeleted);
  }

  final PlanRepository _plans;

  Future<void> _onSubscriptionRequested(
    PlanListSubscriptionRequested event,
    Emitter<PlanListState> emit,
  ) async {
    emit(state.copyWith(status: PlanListStatus.loading));
    await emit.forEach<List<PlanSummary>>(
      _plans.watchSummaries(),
      onData: (summaries) =>
          state.copyWith(status: PlanListStatus.success, summaries: summaries),
      onError: (_, _) => state.copyWith(status: PlanListStatus.failure),
    );
  }

  Future<void> _onPlanCreated(
    PlanListPlanCreated event,
    Emitter<PlanListState> emit,
  ) async {
    final name = event.name.trim();
    // A nameless plan is unfindable in a list that shows nothing else.
    if (name.isEmpty) return;

    try {
      await _plans.savePlan(Plan(id: newId(), name: name, type: event.type));
    } on Object {
      emit(state.copyWith(status: PlanListStatus.failure));
    }
  }

  Future<void> _onPlanDeleted(
    PlanListPlanDeleted event,
    Emitter<PlanListState> emit,
  ) async {
    try {
      await _plans.deletePlan(event.planId);
    } on Object {
      emit(state.copyWith(status: PlanListStatus.failure));
    }
  }
}
