import 'package:bloc/bloc.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:equatable/equatable.dart';

part 'week_template_event.dart';
part 'week_template_state.dart';

/// One training block's weekly template (design screen 4b).
///
/// **Saved as it is edited**, which is what the design asks for — there is
/// no save button, and "Annuler" takes back the last action. That departs
/// from the draft-then-commit shape `docs/PLANNING.md` §5 sets for the plan
/// editor, deliberately: the draft exists to keep keystrokes out of the
/// database, and nothing here is typed. Each edit is one tap and one
/// transaction. The session editor (screen 4c), where values are typed,
/// keeps the draft.
///
/// Edits run **strictly in order**, and each reads the week afresh from the
/// repository rather than from state. Both matter: an edit rewrites the
/// whole week, so two taps in quick succession would otherwise each start
/// from a state the stream has not yet refreshed, and the second would
/// silently erase the first.
class WeekTemplateBloc extends Bloc<WeekTemplateEvent, WeekTemplateState> {
  WeekTemplateBloc(this._plans, {required this._planId, this._blockId})
    : super(const WeekTemplateState()) {
    on<WeekTemplateSubscriptionRequested>(_onSubscriptionRequested);
    on<WeekTemplateEdit>(
      _onEdit,
      // What `bloc_concurrency`'s `sequential()` does, without the
      // dependency for one line.
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// How many edits "Annuler" can walk back.
  static const maxUndo = 50;

  final PlanRepository _plans;
  final String _planId;

  /// The block to edit, or null for the one the plan opens on.
  final String? _blockId;

  Future<void> _onSubscriptionRequested(
    WeekTemplateSubscriptionRequested event,
    Emitter<WeekTemplateState> emit,
  ) async {
    emit(state.copyWith(status: WeekTemplateStatus.loading));
    await emit.forEach<WeekTemplate?>(
      _plans.watchWeekTemplate(_planId, blockId: _blockId),
      onData: (week) => week == null
          ? state.copyWith(status: WeekTemplateStatus.notFound)
          : state.copyWith(status: WeekTemplateStatus.success, week: week),
      onError: (_, _) => state.copyWith(status: WeekTemplateStatus.failure),
    );
  }

  Future<void> _onEdit(
    WeekTemplateEdit event,
    Emitter<WeekTemplateState> emit,
  ) async {
    final week = state.week;
    if (week == null) return;
    emit(state.copyWith(error: () => null));

    try {
      final undo = switch (event) {
        WeekTemplateSessionAssigned(:final weekday, :final templateId) =>
          await _editSlots(
            week,
            (blockId, slots) => _assign(blockId, slots, weekday, templateId),
          ),
        WeekTemplateSessionCreated() => await _createAndAssign(week, event),
        WeekTemplateDayCleared(:final weekday) => await _editSlots(
          week,
          (_, slots) => [
            for (final slot in slots)
              if (slot.weekday != weekday) slot,
          ],
        ),
        WeekTemplateSessionMoved(:final from, :final to) => await _editSlots(
          week,
          (_, slots) => _move(slots, from, to),
        ),
        WeekTemplateDurationChanged(:final weeks) => await _changeDuration(
          week,
          weeks,
        ),
        WeekTemplateBlockStopped() => await _stop(week),
        WeekTemplateBlockCreated() => await _createBlock(event),
        WeekTemplateWeekDuplicated(:final name) => await _duplicate(
          week,
          name,
          emit,
        ),
        WeekTemplateUndoRequested() => await _undo(emit),
      };
      if (undo != null) {
        final stack = [...state.undo, undo];
        emit(
          state.copyWith(
            undo: stack.length > maxUndo
                ? stack.sublist(stack.length - maxUndo)
                : stack,
          ),
        );
      }
    } on BlockOverlapException {
      emit(state.copyWith(error: () => WeekTemplateError.blockOverlap));
    } on PlanTypeConflictException {
      emit(state.copyWith(error: () => WeekTemplateError.planConflict));
    } on Object {
      emit(state.copyWith(error: () => WeekTemplateError.unknown));
    }
  }

  /// Rewrites the week through [change], returning how to take it back —
  /// or null if nothing changed, so a no-op never lands on the undo stack.
  Future<WeekTemplateUndo?> _editSlots(
    WeekTemplate week,
    List<WeeklySlot> Function(String blockId, List<WeeklySlot> slots) change,
  ) async {
    final block = week.block;
    if (block == null || !week.isEditable) return null;
    final before = await _plans.getSlots(block.id);
    final after = change(block.id, before);
    if (_sameWeek(before, after)) return null;
    await _plans.replaceSlots(block.id, after);
    return WeekTemplateSlotsUndo(blockId: block.id, slots: before);
  }

  List<WeeklySlot> _assign(
    String blockId,
    List<WeeklySlot> slots,
    int weekday,
    String templateId,
  ) {
    final existing = slots.where((slot) => slot.weekday == weekday).firstOrNull;
    return [
      for (final slot in slots)
        if (slot.weekday != weekday) slot,
      // The day keeps its row when only the session on it changes.
      (existing ??
              WeeklySlot(
                id: newId(),
                blockId: blockId,
                weekday: weekday,
                sessionTemplateId: templateId,
              ))
          .copyWith(sessionTemplateId: templateId),
    ];
  }

  List<WeeklySlot> _move(List<WeeklySlot> slots, int from, int to) => [
    for (final slot in slots)
      if (slot.weekday == from)
        slot.copyWith(weekday: to)
      else if (slot.weekday == to)
        slot.copyWith(weekday: from)
      else
        slot,
  ];

  Future<WeekTemplateUndo?> _createAndAssign(
    WeekTemplate week,
    WeekTemplateSessionCreated event,
  ) async {
    final name = event.name.trim();
    final block = week.block;
    // A nameless session is unfindable in a picker that shows nothing else.
    if (name.isEmpty || block == null || !week.isEditable) return null;
    final template = SessionTemplate(id: newId(), planId: _planId, name: name);
    await _plans.saveTemplate(template);
    // Undoing this takes the session off the day but leaves the template in
    // the plan: harmless unused, and possibly already given content.
    return await _editSlots(
      week,
      (blockId, slots) => _assign(blockId, slots, event.weekday, template.id),
    );
  }

  Future<WeekTemplateUndo?> _changeDuration(
    WeekTemplate week,
    int weeks,
  ) async {
    final block = week.block;
    if (block == null || !week.isEditable || weeks < week.minDurationWeeks) {
      return null;
    }
    // An explicit end would win over any duration, so setting a length
    // takes back an earlier "stop after this week".
    final changed = block.copyWith(durationWeeks: weeks, explicitEndDate: null);
    if (changed == block) return null;
    await _plans.saveBlock(changed);
    return WeekTemplateBlockUndo(block: block);
  }

  Future<WeekTemplateUndo?> _stop(WeekTemplate week) async {
    final block = week.block;
    final stopDate = week.stopDate;
    if (block == null || stopDate == null) return null;
    await _plans.stopBlock(block.id, on: stopDate);
    return WeekTemplateBlockUndo(block: block);
  }

  /// Not undoable: it is confirmed in a sheet of its own, and a block
  /// starting today could not be deleted again anyway (PRD §4.1).
  Future<WeekTemplateUndo?> _createBlock(WeekTemplateBlockCreated event) async {
    final name = event.name.trim();
    if (name.isEmpty || event.durationWeeks < 1) return null;
    await _plans.saveBlock(
      TrainingBlock(
        id: newId(),
        planId: _planId,
        name: name,
        orderIndex: 0,
        startDate: event.startDate,
        durationWeeks: event.durationWeeks,
      ),
    );
    return null;
  }

  /// Not undoable here: the view moves on to the new block, whose screen has
  /// an undo stack of its own.
  Future<WeekTemplateUndo?> _duplicate(
    WeekTemplate week,
    String name,
    Emitter<WeekTemplateState> emit,
  ) async {
    final block = week.block;
    if (block == null || !week.canDuplicate) return null;
    final copy = await _plans.duplicateBlock(
      block.id,
      newBlockId: newId(),
      name: name,
    );
    emit(state.copyWith(duplicatedBlockId: copy.id));
    return null;
  }

  /// Puts back what the last undoable edit replaced. The step leaves the
  /// stack only once that worked, so a failed undo can be tried again.
  Future<WeekTemplateUndo?> _undo(Emitter<WeekTemplateState> emit) async {
    final step = state.undo.lastOrNull;
    if (step == null) return null;
    switch (step) {
      case WeekTemplateSlotsUndo(:final blockId, :final slots):
        await _plans.replaceSlots(blockId, slots);
      case WeekTemplateBlockUndo(:final block):
        await _plans.saveBlock(block);
    }
    emit(state.copyWith(undo: state.undo.sublist(0, state.undo.length - 1)));
    return null;
  }

  bool _sameWeek(List<WeeklySlot> a, List<WeeklySlot> b) {
    if (a.length != b.length) return false;
    final byWeekday = {for (final slot in a) slot.weekday: slot};
    return b.every((slot) => byWeekday[slot.weekday] == slot);
  }
}
