import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:drift/drift.dart';

part 'planning_dao.g.dart';

/// The planning skeleton: plans, their training blocks, the session
/// templates they own, and each block's weekly template.
@DriftAccessor(tables: [Plans, TrainingBlocks, SessionTemplates, WeeklySlots])
class PlanningDao extends DatabaseAccessor<AppDatabase>
    with _$PlanningDaoMixin, SyncableDao {
  PlanningDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  // --- plans -------------------------------------------------------------

  Stream<List<PlanRow>> watchPlans() => selectLive(plans).watch();

  Future<PlanRow?> findPlan(String id) => findLiveById(plans, id);

  Future<void> savePlan(PlanRow row) => upsertRow(plans, row);

  /// Soft-deletes a plan and everything that only exists to serve it.
  ///
  /// Session logs are pointedly **not** cascaded: a deleted plan's history
  /// stays visible forever (PRD §4.1), which is the whole reason logs are
  /// snapshots rather than joins.
  Future<void> deletePlan(String id) => transaction(() async {
    await softDeleteWhere(
      weeklySlots,
      (t) => t.blockId.isInQuery(_blockIdsOf(id)),
    );
    await softDeleteWhere(trainingBlocks, (t) => t.planId.equals(id));
    await softDeleteWhere(sessionTemplates, (t) => t.planId.equals(id));
    await softDeleteRow(plans, id);
  });

  // --- training blocks ---------------------------------------------------

  /// Blocks of a plan, oldest first.
  ///
  /// Ordered on `startDate` rather than `orderIndex`: blocks in a plan
  /// cannot overlap, so their dates are already a total order, and one that
  /// no editing mistake can put out of step with the calendar.
  Stream<List<TrainingBlockRow>> watchBlocks(String planId) =>
      _blocksOf(planId).watch();

  Future<List<TrainingBlockRow>> getBlocks(String planId) =>
      _blocksOf(planId).get();

  Future<TrainingBlockRow?> findBlock(String id) =>
      findLiveById(trainingBlocks, id);

  /// Every live block belonging to a live plan of [type], across all plans.
  ///
  /// This is what the "at most one active plan per type" rule of PRD §4.1 is
  /// checked against.
  Future<List<TrainingBlockRow>> getBlocksOfType(PlanType type) {
    final query =
        select(trainingBlocks).join([
          innerJoin(plans, plans.id.equalsExp(trainingBlocks.planId)),
        ])..where(
          trainingBlocks.deletedAt.isNull() &
              plans.deletedAt.isNull() &
              plans.type.equalsValue(type),
        );
    return query.map((row) => row.readTable(trainingBlocks)).get();
  }

  Future<void> saveBlock(TrainingBlockRow row) =>
      upsertRow(trainingBlocks, row);

  Future<void> deleteBlock(String id) => transaction(() async {
    await softDeleteWhere(weeklySlots, (t) => t.blockId.equals(id));
    await softDeleteRow(trainingBlocks, id);
  });

  // --- session templates -------------------------------------------------

  Stream<List<SessionTemplateRow>> watchTemplates(String planId) =>
      watchLiveWhere(sessionTemplates, (t) => t.planId.equals(planId));

  Future<void> saveTemplate(SessionTemplateRow row) =>
      upsertRow(sessionTemplates, row);

  /// Soft-deletes a template and clears the weekly slots pointing at it.
  ///
  /// A slot left pointing at a deleted template would schedule a session
  /// with no content — an occurrence the runner cannot open.
  Future<void> deleteTemplate(String id) => transaction(() async {
    await softDeleteWhere(weeklySlots, (t) => t.sessionTemplateId.equals(id));
    await softDeleteRow(sessionTemplates, id);
  });

  /// Everything the plan list reads, in one pass.
  ///
  /// Read whole rather than per plan: a handful of plans, a handful of
  /// blocks each and at most seven slots per block, against one query per
  /// plan per stream if the caller assembled it itself.
  Future<PlanningSources> loadSummarySources() async => PlanningSources(
    plans: await selectLive(plans).get(),
    blocks: await selectLive(trainingBlocks).get(),
    slots: await selectLive(weeklySlots).get(),
  );

  /// [loadSummarySources], re-read whenever any of its three tables change.
  Stream<PlanningSources> watchSummarySources() =>
      watchRecomputed([plans, trainingBlocks, weeklySlots], loadSummarySources);

  /// The ids of a plan's blocks, deleted ones included.
  ///
  /// Deleted rows are included so a cascade reaches the deviations of a
  /// block that was retired earlier and never cleaned up.
  Future<List<String>> blockIdsOf(String planId) async {
    final query = selectOnly(trainingBlocks)
      ..addColumns([trainingBlocks.id])
      ..where(trainingBlocks.planId.equals(planId));
    final rows = await query.get();
    return [for (final row in rows) row.read(trainingBlocks.id)!];
  }

  /// The ids of a plan's session templates, deleted ones included.
  Future<List<String>> templateIdsOf(String planId) async {
    final query = selectOnly(sessionTemplates)
      ..addColumns([sessionTemplates.id])
      ..where(sessionTemplates.planId.equals(planId));
    final rows = await query.get();
    return [for (final row in rows) row.read(sessionTemplates.id)!];
  }

  // --- weekly slots ------------------------------------------------------

  Stream<List<WeeklySlotRow>> watchSlots(String blockId) =>
      (selectLive(weeklySlots)
            ..where((t) => t.blockId.equals(blockId))
            ..orderBy([(t) => OrderingTerm(expression: t.weekday)]))
          .watch();

  /// Puts [row] on its weekday, retiring whatever was there.
  ///
  /// The previous slot is soft-deleted in the same transaction as the
  /// insert, because the partial unique index tolerates a second row on a
  /// weekday only while the first one is deleted.
  Future<void> setSlot(WeeklySlotRow row) => transaction(() async {
    await softDeleteWhere(
      weeklySlots,
      (t) =>
          t.blockId.equals(row.blockId) &
          t.weekday.equals(row.weekday) &
          t.id.equals(row.id).not(),
    );
    await upsertRow(weeklySlots, row);
  });

  Future<void> clearSlot({required String blockId, required int weekday}) =>
      softDeleteWhere(
        weeklySlots,
        (t) => t.blockId.equals(blockId) & t.weekday.equals(weekday),
      );

  SimpleSelectStatement<$TrainingBlocksTable, TrainingBlockRow> _blocksOf(
    String planId,
  ) => selectLive(trainingBlocks)
    ..where((t) => t.planId.equals(planId))
    ..orderBy([(t) => OrderingTerm(expression: t.startDate)]);

  /// The ids of every block of a plan, deleted ones included: a cascade
  /// reaches rows whose block was retired earlier.
  JoinedSelectStatement<$TrainingBlocksTable, TrainingBlockRow> _blockIdsOf(
    String planId,
  ) => selectOnly(trainingBlocks)
    ..addColumns([trainingBlocks.id])
    ..where(trainingBlocks.planId.equals(planId));
}

/// The rows one plan-list computation reads, as a single value.
class PlanningSources {
  const PlanningSources({
    required this.plans,
    required this.blocks,
    required this.slots,
  });

  final List<PlanRow> plans;
  final List<TrainingBlockRow> blocks;
  final List<WeeklySlotRow> slots;
}
