import 'package:coach_app/core/database/dao/planning_dao.dart';
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

  Future<void> setSlot(WeeklySlot slot);

  Future<void> clearSlot({required String blockId, required int weekday});
}

/// Drift-backed [PlanRepository].
///
/// Every rule PRD §4.1 states about plans lives here rather than in a bloc:
/// the schema cannot express "blocks may not overlap" — SQLite has no
/// exclusion constraints — and a rule enforced in one editor screen is a
/// rule the next writer forgets.
class DriftPlanRepository implements PlanRepository {
  const DriftPlanRepository(this._dao);

  final PlanningDao _dao;

  @override
  Stream<List<Plan>> watchPlans() => _dao.watchPlans().map(
    (rows) => _byName(rows.map((row) => row.toDomain()), (plan) => plan.name),
  );

  @override
  Future<Plan?> findPlan(String id) async =>
      (await _dao.findPlan(id))?.toDomain();

  @override
  Future<void> savePlan(Plan plan) => _dao.savePlan(plan.toRow(_dao.now()));

  @override
  Future<void> deletePlan(String id) => _dao.deletePlan(id);

  @override
  Stream<List<TrainingBlock>> watchBlocks(String planId) =>
      _dao.watchBlocks(planId).map(
        (rows) => rows.map((row) => row.toDomain()).toList(),
      );

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
    await _dao.deleteBlock(id);
  }

  @override
  Future<void> stopBlock(String id, {required DateOnly on}) async {
    final row = await _dao.findBlock(id);
    if (row == null) return;
    await saveBlock(row.toDomain().copyWith(explicitEndDate: on));
  }

  @override
  Stream<List<SessionTemplate>> watchTemplates(String planId) =>
      _dao.watchTemplates(planId).map(
        (rows) => _byName(
          rows.map((row) => row.toDomain()),
          (template) => template.name,
        ),
      );

  @override
  Future<void> saveTemplate(SessionTemplate template) =>
      _dao.saveTemplate(template.toRow(_dao.now()));

  @override
  Future<void> deleteTemplate(String id) => _dao.deleteTemplate(id);

  @override
  Stream<List<WeeklySlot>> watchSlots(String blockId) => _dao
      .watchSlots(blockId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> setSlot(WeeklySlot slot) =>
      _dao.setSlot(slot.toRow(_dao.now()));

  @override
  Future<void> clearSlot({required String blockId, required int weekday}) =>
      _dao.clearSlot(blockId: blockId, weekday: weekday);

  DateOnly get _today => DateOnly.today(clock: _dao.now);

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
      items.toList()
        ..sort(
          (a, b) => foldForSearch(name(a)).compareTo(foldForSearch(name(b))),
        );
}
