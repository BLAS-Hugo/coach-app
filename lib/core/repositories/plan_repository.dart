import 'dart:math' as math;

import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/text_normalisation.dart';

/// Thrown when a block would overlap a sibling in the same plan (PRD §4.1).
class BlockOverlapException implements Exception {
  const BlockOverlapException(this.blockId, this.conflictingBlockId);

  final String blockId;
  final String conflictingBlockId;

  @override
  String toString() =>
      'Block $blockId overlaps block $conflictingBlockId in the same plan';
}

/// Thrown when a block would overlap a block of a *different* plan of the
/// same type.
class PlanTypeConflictException implements Exception {
  const PlanTypeConflictException(this.blockId, this.conflictingPlanId);

  final String blockId;
  final String conflictingPlanId;

  @override
  String toString() =>
      'Block $blockId overlaps plan $conflictingPlanId of the same type';
}

/// Thrown when deleting a block that has already started.
class BlockStartedException implements Exception {
  const BlockStartedException(this.blockId);

  final String blockId;

  @override
  String toString() => 'Block $blockId has started and can only be stopped';
}

/// Plans, their blocks, their session templates and each block's weekly
/// template.
abstract interface class PlanRepository {
  Stream<List<Plan>> watchPlans();

  /// Every live plan with the state the plan list renders: which block is
  /// running, how far into it today is, and how many sessions its week
  /// holds. Re-emitted whenever any of that changes.
  Stream<List<PlanSummary>> watchSummaries();

  Future<Plan?> findPlan(String id);

  Future<void> savePlan(Plan plan);

  Future<void> deletePlan(String id);

  Stream<List<TrainingBlock>> watchBlocks(String planId);

  Future<void> saveBlock(TrainingBlock block);

  Future<void> deleteBlock(String id);

  Future<void> stopBlock(String id, {required DateOnly on});

  Stream<List<SessionTemplate>> watchTemplates(String planId);

  Future<void> saveTemplate(SessionTemplate template);

  Future<void> deleteTemplate(String id);

  Stream<List<WeeklySlot>> watchSlots(String blockId);

  Future<List<WeeklySlot>> getSlots(String blockId);

  Future<void> setSlot(WeeklySlot slot);

  Future<void> clearSlot({required String blockId, required int weekday});

  /// Makes [slots] the entire weekly template of [blockId], in one
  /// transaction.
  ///
  /// Throws [ArgumentError] if two slots share a weekday or one belongs to
  /// another block: either would leave the week meaning something other
  /// than what the caller handed over.
  Future<void> replaceSlots(String blockId, List<WeeklySlot> slots);

  /// One block's weekly template with everything the editor renders around
  /// it (design screen 4b), re-emitted whenever any of it changes.
  ///
  /// [blockId] picks the block; without one, the block covering today is
  /// taken, else the next to start, else the last to have run. Emits null
  /// while the plan does not exist.
  Stream<WeekTemplate?> watchWeekTemplate(String planId, {String? blockId});

  /// Starts a new block named [name] the day after [blockId] ends — or
  /// today, if that day has passed — for as many weeks as it ran, seeded
  /// with a copy of its weekly template: the "Dupliquer la semaine, puis
  /// ajuster" step of PRD §6.4.
  ///
  /// Returns the new block. Throws [StateError] if the source block is
  /// ongoing — there is no day after a block that never ends — and the
  /// overlap exceptions of [saveBlock] if a sibling already holds those
  /// dates.
  Future<TrainingBlock> duplicateBlock(
    String blockId, {
    required String newBlockId,
    required String name,
  });
}

/// Drift-backed [PlanRepository].
///
/// Every rule PRD §4.1 states about plans lives here rather than in a bloc:
/// the schema cannot express "blocks may not overlap" — SQLite has no
/// exclusion constraints — and a rule enforced in one editor screen is a
/// rule the next writer forgets.
class DriftPlanRepository implements PlanRepository {
  const DriftPlanRepository(this._dao, this._content, this._scheduling);

  /// The gap left between the `orderIndex` of consecutive blocks, as
  /// content rows leave between theirs (`docs/PLANNING.md` §2).
  static const _blockOrderGap = 100;

  final PlanningDao _dao;

  /// Reached to cascade deletes and to size templates for the weekly
  /// template. A plan owns its templates' content and its blocks'
  /// deviations, but each has its own repository for everything else.
  final ContentDao _content;
  final SchedulingDao _scheduling;

  @override
  Stream<List<Plan>> watchPlans() => _dao.watchPlans().map(
    (rows) => _byName(rows.map((row) => row.toDomain()), (plan) => plan.name),
  );

  @override
  Stream<List<PlanSummary>> watchSummaries() =>
      _dao.watchSummarySources().map(_summarise);

  @override
  Future<Plan?> findPlan(String id) async =>
      (await _dao.findPlan(id))?.toDomain();

  @override
  Future<void> savePlan(Plan plan) => _dao.savePlan(plan.toRow(_dao.now()));

  @override
  Future<void> deletePlan(String id) => _dao.transaction(() async {
    await _content.deleteContentOfTemplates(await _dao.templateIdsOf(id));
    await _scheduling.deleteDeviationsOfBlocks(await _dao.blockIdsOf(id));
    await _dao.deletePlan(id);
  });

  @override
  Stream<List<TrainingBlock>> watchBlocks(String planId) => _dao
      .watchBlocks(planId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> saveBlock(TrainingBlock block) async {
    await _assertNoOverlap(block);
    await _dao.saveBlock(block.toRow(_dao.now()));
  }

  @override
  Future<void> deleteBlock(String id) async {
    final row = await _dao.findBlock(id);
    if (row == null) return;
    final block = row.toDomain();
    if (!block.startDate.isAfter(_today)) {
      // Sessions may already have been logged against it. Stopping keeps
      // those days meaningful; deleting would strand them (PRD §4.1).
      throw BlockStartedException(id);
    }
    await _dao.transaction(() async {
      await _scheduling.deleteDeviationsOfBlocks([id]);
      await _dao.deleteBlock(id);
    });
  }

  @override
  Future<void> stopBlock(String id, {required DateOnly on}) async {
    final row = await _dao.findBlock(id);
    if (row == null) return;
    await saveBlock(row.toDomain().copyWith(explicitEndDate: on));
  }

  @override
  Stream<List<SessionTemplate>> watchTemplates(String planId) => _dao
      .watchTemplates(planId)
      .map(
        (rows) => _byName(
          rows.map((row) => row.toDomain()),
          (template) => template.name,
        ),
      );

  @override
  Future<void> saveTemplate(SessionTemplate template) =>
      _dao.saveTemplate(template.toRow(_dao.now()));

  @override
  Future<void> deleteTemplate(String id) => _dao.transaction(() async {
    await _content.deleteContentOfTemplates([id]);
    await _dao.deleteTemplate(id);
  });

  @override
  Stream<List<WeeklySlot>> watchSlots(String blockId) => _dao
      .watchSlots(blockId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> setSlot(WeeklySlot slot) => _dao.setSlot(slot.toRow(_dao.now()));

  @override
  Future<void> clearSlot({required String blockId, required int weekday}) =>
      _dao.clearSlot(blockId: blockId, weekday: weekday);

  @override
  Future<List<WeeklySlot>> getSlots(String blockId) async =>
      [for (final row in await _dao.getSlots(blockId)) row.toDomain()]
        ..sort((a, b) => a.weekday.compareTo(b.weekday));

  @override
  Future<void> replaceSlots(String blockId, List<WeeklySlot> slots) async {
    final weekdays = <int>{};
    for (final slot in slots) {
      if (slot.blockId != blockId) {
        throw ArgumentError.value(slot, 'slots', 'belongs to another block');
      }
      if (!weekdays.add(slot.weekday)) {
        throw ArgumentError.value(slot, 'slots', 'shares its weekday');
      }
    }
    final at = _dao.now();
    await _dao.replaceSlots(blockId, [
      for (final slot in slots) slot.toRow(at),
    ]);
  }

  @override
  Stream<WeekTemplate?> watchWeekTemplate(String planId, {String? blockId}) =>
      _dao.watchRecomputed([
        _dao.plans,
        _dao.trainingBlocks,
        _dao.sessionTemplates,
        _dao.weeklySlots,
        _content.exerciseEntries,
        _content.plannedSets,
        _content.enduranceBlocks,
      ], () => _loadWeekTemplate(planId, blockId));

  @override
  Future<TrainingBlock> duplicateBlock(
    String blockId, {
    required String newBlockId,
    required String name,
  }) => _dao.transaction(() async {
    final row = await _dao.findBlock(blockId);
    if (row == null) throw StateError('Block $blockId does not exist');
    final source = row.toDomain();
    final end = source.endDate;
    final weeks = source.weekCount;
    if (end == null || weeks == null) {
      throw StateError('Block $blockId is ongoing and has no day after it');
    }

    final siblings = await _dao.getBlocks(source.planId);
    final copy = TrainingBlock(
      id: newBlockId,
      planId: source.planId,
      name: name,
      orderIndex:
          siblings.fold(0, (last, block) => math.max(last, block.orderIndex)) +
          _blockOrderGap,
      // The day after the source, unless that is already behind: a copy of
      // a block that ended months ago would otherwise open on a run of
      // days the user could only ever have missed.
      startDate: end.isBefore(_today) ? _today : end.addDays(1),
      // As many weeks as the source actually ran: a block stopped early is
      // duplicated at its shortened length, which is what it was worth.
      durationWeeks: weeks,
    );
    await saveBlock(copy);
    await replaceSlots(copy.id, [
      for (final slot in await getSlots(blockId))
        slot.copyWith(id: newId(), blockId: copy.id),
    ]);
    return copy;
  });

  DateOnly get _today => DateOnly.today(clock: _dao.now);

  Future<WeekTemplate?> _loadWeekTemplate(
    String planId,
    String? blockId,
  ) async {
    final planRow = await _dao.findPlan(planId);
    if (planRow == null) return null;
    final today = _today;
    final blocks = [
      for (final row in await _dao.getBlocks(planId)) row.toDomain(),
    ];
    final block = blockId == null
        ? _defaultBlock(blocks, today)
        : blocks.where((candidate) => candidate.id == blockId).firstOrNull;

    final templates = await _dao.getTemplates(planId);
    final counts = await _content.loadContentCounts([
      for (final row in templates) row.id,
    ]);

    return WeekTemplate(
      plan: planRow.toDomain(),
      today: today,
      blocks: blocks,
      block: block,
      slots: block == null ? const [] : await getSlots(block.id),
      templates: _byName([
        for (final row in templates)
          SessionTemplateSummary(
            template: row.toDomain(),
            exerciseCount: counts[row.id]!.exercises,
            setCount: counts[row.id]!.sets,
            enduranceBlockCount: counts[row.id]!.enduranceBlocks,
          ),
      ], (summary) => summary.template.name),
    );
  }

  /// The block a plan opens on: the one running today, else the next to
  /// start, else the last to have run. [blocks] is chronological.
  TrainingBlock? _defaultBlock(List<TrainingBlock> blocks, DateOnly today) =>
      blocks.where((block) => block.covers(today)).firstOrNull ??
      blocks.where((block) => block.startDate.isAfter(today)).firstOrNull ??
      blocks.lastOrNull;

  /// Projects the three source tables onto one card per plan.
  List<PlanSummary> _summarise(PlanningSources sources) {
    final today = _today;
    final blocksByPlan = <String, List<TrainingBlock>>{};
    for (final row in sources.blocks) {
      (blocksByPlan[row.planId] ??= []).add(row.toDomain());
    }
    final slotCounts = <String, int>{};
    for (final row in sources.slots) {
      slotCounts[row.blockId] = (slotCounts[row.blockId] ?? 0) + 1;
    }

    final summaries = <PlanSummary>[];
    for (final planRow in sources.plans) {
      final plan = planRow.toDomain();
      // Chronological, which is also the order the card numbers them in:
      // blocks in a plan cannot overlap, so their dates are a total order.
      final blocks = (blocksByPlan[plan.id] ?? [])
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      final index = blocks.indexWhere((block) => block.covers(today));
      final current = index == -1 ? null : blocks[index];

      summaries.add(
        PlanSummary(
          plan: plan,
          blockCount: blocks.length,
          currentBlock: current,
          currentBlockOrdinal: current == null ? null : index + 1,
          weekIndex: current?.weekIndexOf(today),
          weekCount: current?.weekCount,
          sessionsPerWeek: current == null ? 0 : slotCounts[current.id] ?? 0,
        ),
      );
    }

    return _byName(summaries, (summary) => summary.plan.name);
  }

  /// Checks [block] against its siblings and against every other plan of the
  /// same type.
  ///
  /// The second check is the one that is easy to miss: two strength plans
  /// whose blocks overlap are both "active" on those days, and the day view
  /// shows at most one session per type (PRD §5.1). Blocked at write time,
  /// where the user can still be told which block is in the way — the
  /// occurrence engine has no way to report it later.
  Future<void> _assertNoOverlap(TrainingBlock block) async {
    for (final row in await _dao.getBlocks(block.planId)) {
      if (row.id == block.id) continue;
      if (block.overlaps(row.toDomain())) {
        throw BlockOverlapException(block.id, row.id);
      }
    }

    final plan = await _dao.findPlan(block.planId);
    if (plan == null) return;
    for (final row in await _dao.getBlocksOfType(plan.type)) {
      if (row.planId == block.planId) continue;
      if (block.overlaps(row.toDomain())) {
        throw PlanTypeConflictException(block.id, row.planId);
      }
    }
  }

  /// Ordered on the folded name: SQLite's collations are ASCII-only, so
  /// sorting in SQL would file "Épaules" after "Squat".
  List<T> _byName<T>(Iterable<T> items, String Function(T) name) =>
      items.toList()..sort(
        (a, b) => foldForSearch(name(a)).compareTo(foldForSearch(name(b))),
      );
}
