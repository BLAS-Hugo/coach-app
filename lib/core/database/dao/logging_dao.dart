import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/logging_tables.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:drift/drift.dart';

part 'logging_dao.g.dart';

/// Session logs and the content performed inside them.
@DriftAccessor(
  tables: [SessionLogs, LoggedExercises, LoggedSets, LoggedBlocks],
)
class LoggingDao extends DatabaseAccessor<AppDatabase>
    with _$LoggingDaoMixin, SyncableDao {
  LoggingDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  Stream<List<SessionLogRow>> watchLogs(DateRange range) =>
      (selectLive(sessionLogs)
            ..where(
              (t) => t.date.isBetweenValues(
                range.start.epochDay,
                range.end.epochDay,
              ),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.date)]))
          .watch();

  Future<SessionLogRow?> findLog(String id) => findLiveById(sessionLogs, id);

  Future<SessionLogRow?> findLogForOccurrence({
    required String planId,
    required DateOnly date,
  }) =>
      (selectLive(sessionLogs)..where(
            (t) => t.planId.equals(planId) & t.date.equals(date.epochDay),
          ))
          .getSingleOrNull();

  Stream<List<LoggedExerciseRow>> watchLoggedExercises(String logId) =>
      (selectLive(loggedExercises)
            ..where((t) => t.sessionLogId.equals(logId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Stream<List<LoggedSetRow>> watchLoggedSets(String loggedExerciseId) =>
      (selectLive(loggedSets)
            ..where((t) => t.loggedExerciseId.equals(loggedExerciseId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  /// Logged blocks in performance order.
  ///
  /// Ordered on `orderIndex` *then* `roundIndex`, because a repeat group's
  /// rounds share an order index — round 2 of a 6 × 400 m group is its own
  /// row sitting at the same position in the session.
  Stream<List<LoggedBlockRow>> watchLoggedBlocks(String logId) =>
      (selectLive(loggedBlocks)
            ..where((t) => t.sessionLogId.equals(logId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.orderIndex),
              (t) => OrderingTerm(expression: t.roundIndex),
            ]))
          .watch();

  /// Writes a log and everything performed inside it, in one transaction.
  Future<void> createLog({
    required SessionLogRow log,
    required List<LoggedExerciseRow> exercises,
    required List<LoggedSetRow> sets,
    required List<LoggedBlockRow> blocks,
  }) => transaction(() async {
    await upsertRow(sessionLogs, log);
    await upsertRows(loggedExercises, exercises);
    await upsertRows(loggedSets, sets);
    await upsertRows(loggedBlocks, blocks);
  });

  Future<void> saveLog(SessionLogRow row) => upsertRow(sessionLogs, row);

  Future<void> saveLoggedExercise(LoggedExerciseRow row) =>
      upsertRow(loggedExercises, row);

  Future<void> saveLoggedSet(LoggedSetRow row) => upsertRow(loggedSets, row);

  Future<void> saveLoggedBlock(LoggedBlockRow row) =>
      upsertRow(loggedBlocks, row);

  Future<void> deleteLog(String id) => transaction(() async {
    await softDeleteWhere(
      loggedSets,
      (t) => t.loggedExerciseId.isInQuery(_loggedExerciseIdsOf(id)),
    );
    await softDeleteWhere(loggedExercises, (t) => t.sessionLogId.equals(id));
    await softDeleteWhere(loggedBlocks, (t) => t.sessionLogId.equals(id));
    await softDeleteRow(sessionLogs, id);
  });

  /// The ids of a log's exercises, deleted ones included.
  JoinedSelectStatement<$LoggedExercisesTable, LoggedExerciseRow>
  _loggedExerciseIdsOf(String logId) => selectOnly(loggedExercises)
    ..addColumns([loggedExercises.id])
    ..where(loggedExercises.sessionLogId.equals(logId));
}
