import 'dart:async';

import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/deviation_tables.dart';
import 'package:coach_app/core/database/tables/logging_tables.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:drift/drift.dart';

part 'scheduling_dao.g.dart';

/// Everything the occurrence engine reads, plus the two deviation tables it
/// reads them through.
@DriftAccessor(
  tables: [
    Plans,
    TrainingBlocks,
    WeeklySlots,
    WeekOverrides,
    OccurrenceMoves,
    SessionLogs,
  ],
)
class SchedulingDao extends DatabaseAccessor<AppDatabase>
    with _$SchedulingDaoMixin, SyncableDao {
  SchedulingDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  /// Every row the occurrence engine needs for [range], read together.
  ///
  /// Blocks, slots, overrides and moves are read whole rather than filtered
  /// by date: a block's end date is derived, not stored, so SQL cannot tell
  /// which blocks a window touches. The tables are small — a plan has a
  /// handful of blocks and at most seven slots each.
  ///
  /// Logs are the exception and are clipped to [range], because that table
  /// grows forever. Clipping is safe: an occurrence carried onto another
  /// date by a move is keyed on the date it lands on, which is inside the
  /// window by the time the engine looks a log up.
  Future<SchedulingSources> loadSources(DateRange range) async =>
      SchedulingSources(
        plans: await selectLive(plans).get(),
        blocks: await selectLive(trainingBlocks).get(),
        slots: await selectLive(weeklySlots).get(),
        overrides: await selectLive(weekOverrides).get(),
        moves: await selectLive(occurrenceMoves).get(),
        logs:
            await (selectLive(sessionLogs)..where(
                  (t) => t.date.isBetweenValues(
                    range.start.epochDay,
                    range.end.epochDay,
                  ),
                ))
                .get(),
      );

  /// [loadSources], re-read whenever any table it touches changes.
  ///
  /// Six tables feed one computation, so this listens to the database's
  /// update stream rather than combining six query streams: one trigger,
  /// one read, one emission per change instead of six racing partial
  /// states. The subscription is opened *before* the first read, because a
  /// write landing in between would otherwise never reach a listener.
  Stream<SchedulingSources> watchSources(DateRange range) {
    final updates = attachedDatabase.tableUpdates(
      TableUpdateQuery.onAllTables([
        plans,
        trainingBlocks,
        weeklySlots,
        weekOverrides,
        occurrenceMoves,
        sessionLogs,
      ]),
    );

    late StreamController<SchedulingSources> controller;
    StreamSubscription<void>? subscription;
    var reading = false;
    var stale = false;

    Future<void> reload() async {
      // A write arriving mid-read marks the result stale rather than
      // starting a second read, so a burst of updates collapses into one
      // extra pass instead of a queue of them.
      if (reading) {
        stale = true;
        return;
      }
      reading = true;
      do {
        stale = false;
        try {
          final sources = await loadSources(range);
          if (controller.isClosed) break;
          controller.add(sources);
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      } while (stale);
      reading = false;
    }

    controller = StreamController<SchedulingSources>(
      onListen: () {
        subscription = updates.listen((_) => reload());
        unawaited(reload());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  Future<PlanRow?> findPlan(String id) => findLiveById(plans, id);

  Future<TrainingBlockRow?> findBlock(String id) =>
      findLiveById(trainingBlocks, id);

  // --- week overrides ----------------------------------------------------

  Stream<List<WeekOverrideRow>> watchOverrides(String blockId) =>
      (selectLive(weekOverrides)
            ..where((t) => t.blockId.equals(blockId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.weekIndex),
              (t) => OrderingTerm(expression: t.weekday),
            ]))
          .watch();

  /// Puts [row] on its week and weekday, retiring whatever was there.
  Future<void> setOverride(WeekOverrideRow row) => transaction(() async {
    await softDeleteWhere(
      weekOverrides,
      (t) =>
          t.blockId.equals(row.blockId) &
          t.weekIndex.equals(row.weekIndex) &
          t.weekday.equals(row.weekday) &
          t.id.equals(row.id).not(),
    );
    await upsertRow(weekOverrides, row);
  });

  Future<void> clearOverride({
    required String blockId,
    required int weekIndex,
    required int weekday,
  }) => softDeleteWhere(
    weekOverrides,
    (t) =>
        t.blockId.equals(blockId) &
        t.weekIndex.equals(weekIndex) &
        t.weekday.equals(weekday),
  );

  // --- moves -------------------------------------------------------------

  Stream<List<OccurrenceMoveRow>> watchMoves(String blockId) =>
      (selectLive(occurrenceMoves)
            ..where((t) => t.blockId.equals(blockId))
            ..orderBy([(t) => OrderingTerm(expression: t.date)]))
          .watch();

  Future<OccurrenceMoveRow?> findMove({
    required String blockId,
    required DateOnly date,
  }) =>
      (selectLive(occurrenceMoves)..where(
            (t) => t.blockId.equals(blockId) & t.date.equals(date.epochDay),
          ))
          .getSingleOrNull();

  /// Records [row], replacing any move already leaving its source date.
  Future<void> setMove(OccurrenceMoveRow row) => transaction(() async {
    await softDeleteWhere(
      occurrenceMoves,
      (t) =>
          t.blockId.equals(row.blockId) &
          t.date.equals(row.date.epochDay) &
          t.id.equals(row.id).not(),
    );
    await upsertRow(occurrenceMoves, row);
  });

  /// Soft-deletes every deviation belonging to [blockIds].
  ///
  /// A move or an override outliving its block would be dead weight the
  /// engine reads on every recomputation and never applies.
  Future<void> deleteDeviationsOfBlocks(Iterable<String> blockIds) {
    final ids = blockIds.toList();
    if (ids.isEmpty) return Future.value();
    return transaction(() async {
      await softDeleteWhere(weekOverrides, (t) => t.blockId.isIn(ids));
      await softDeleteWhere(occurrenceMoves, (t) => t.blockId.isIn(ids));
    });
  }

  Future<void> clearMove({required String blockId, required DateOnly date}) =>
      softDeleteWhere(
        occurrenceMoves,
        (t) => t.blockId.equals(blockId) & t.date.equals(date.epochDay),
      );
}

/// The rows one occurrence computation reads, as a single value.
///
/// Kept as rows rather than domain models so the mapping stays in one place
/// — the repository — instead of being spread across the DAO.
class SchedulingSources {
  const SchedulingSources({
    required this.plans,
    required this.blocks,
    required this.slots,
    required this.overrides,
    required this.moves,
    required this.logs,
  });

  final List<PlanRow> plans;
  final List<TrainingBlockRow> blocks;
  final List<WeeklySlotRow> slots;
  final List<WeekOverrideRow> overrides;
  final List<OccurrenceMoveRow> moves;
  final List<SessionLogRow> logs;
}
