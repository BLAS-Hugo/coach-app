import 'package:coach_app/core/database/dao/logging_dao.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';

/// Thrown when a plan would end up with two logs on one date.
class DuplicateSessionLogException implements Exception {
  const DuplicateSessionLogException(this.planId, this.date);

  final String planId;
  final DateOnly date;

  @override
  String toString() => 'Plan $planId already has a session log on $date';
}

/// Session logs: what was actually done, or explicitly not done.
///
/// A log is a snapshot. Once written, no edit to the plan touches it, which
/// is what lets a block be reshaped mid-flight without rewriting history
/// (PRD G4).
abstract interface class SessionLogRepository {
  Stream<List<SessionLog>> watchLogs(DateRange range);

  Future<SessionLog?> findLog(String id);

  /// The log materialised for an occurrence, if there is one.
  Future<SessionLog?> findLogForOccurrence({
    required String planId,
    required DateOnly date,
  });

  Stream<List<LoggedExercise>> watchLoggedExercises(String logId);

  Stream<List<LoggedSet>> watchLoggedSets(String loggedExerciseId);

  Stream<List<LoggedBlock>> watchLoggedBlocks(String logId);

  /// Materialises a session: the log and all of its content, in one
  /// transaction.
  ///
  /// Throws [ArgumentError] for a log that was never started and is not a
  /// skip, and [DuplicateSessionLogException] if the plan already has a log
  /// on that date.
  Future<void> createLog({
    required SessionLog log,
    List<LoggedExercise> exercises,
    Map<String, List<LoggedSet>> setsByExercise,
    List<LoggedBlock> blocks,
  });

  Future<void> saveLog(SessionLog log);

  Future<void> saveLoggedExercise(LoggedExercise exercise);

  Future<void> saveLoggedSet(LoggedSet set);

  Future<void> saveLoggedBlock(LoggedBlock block);

  Future<void> deleteLog(String id);
}

/// Drift-backed [SessionLogRepository].
class DriftSessionLogRepository implements SessionLogRepository {
  const DriftSessionLogRepository(this._dao);

  /// The gap left between consecutive `orderIndex` values, so a set added
  /// mid-session slots between two others without renumbering the list.
  static const _orderGap = 100;

  final LoggingDao _dao;

  @override
  Stream<List<SessionLog>> watchLogs(DateRange range) => _dao
      .watchLogs(range)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<SessionLog?> findLog(String id) async =>
      (await _dao.findLog(id))?.toDomain();

  @override
  Future<SessionLog?> findLogForOccurrence({
    required String planId,
    required DateOnly date,
  }) async =>
      (await _dao.findLogForOccurrence(planId: planId, date: date))?.toDomain();

  @override
  Stream<List<LoggedExercise>> watchLoggedExercises(String logId) => _dao
      .watchLoggedExercises(logId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Stream<List<LoggedSet>> watchLoggedSets(String loggedExerciseId) => _dao
      .watchLoggedSets(loggedExerciseId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Stream<List<LoggedBlock>> watchLoggedBlocks(String logId) => _dao
      .watchLoggedBlocks(logId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> createLog({
    required SessionLog log,
    List<LoggedExercise> exercises = const [],
    Map<String, List<LoggedSet>> setsByExercise = const {},
    List<LoggedBlock> blocks = const [],
  }) async {
    if (log.startedAt == null && log.status != SessionStatus.skipped) {
      throw ArgumentError.value(
        log.status,
        'log.status',
        'A log with no startedAt describes a session that was neither '
            'performed nor declined; only a skip may be unstarted',
      );
    }

    final existing = await _dao.findLogForOccurrence(
      planId: log.planId,
      date: log.date,
    );
    if (existing != null && existing.id != log.id) {
      // The engine keys logs by plan and date, so a second one would
      // silently shadow the first instead of showing up as a conflict.
      throw DuplicateSessionLogException(log.planId, log.date);
    }

    final at = _dao.now();
    await _dao.createLog(
      log: log.toRow(at),
      exercises: [
        for (final (index, exercise) in exercises.indexed)
          exercise
              .copyWith(sessionLogId: log.id, orderIndex: index * _orderGap)
              .toRow(at),
      ],
      sets: [
        for (final exercise in exercises)
          for (final (index, set)
              in (setsByExercise[exercise.id] ?? const []).indexed)
            set
                .copyWith(
                  loggedExerciseId: exercise.id,
                  orderIndex: index * _orderGap,
                )
                .toRow(at),
      ],
      // Blocks keep the order indices they arrive with: a repeat group's
      // rounds deliberately share one, and renumbering would flatten "round
      // 2 of the same block" into "a different block".
      blocks: [
        for (final block in blocks)
          block.copyWith(sessionLogId: log.id).toRow(at),
      ],
    );
  }

  @override
  Future<void> saveLog(SessionLog log) => _dao.saveLog(log.toRow(_dao.now()));

  @override
  Future<void> saveLoggedExercise(LoggedExercise exercise) =>
      _dao.saveLoggedExercise(exercise.toRow(_dao.now()));

  @override
  Future<void> saveLoggedSet(LoggedSet set) =>
      _dao.saveLoggedSet(set.toRow(_dao.now()));

  @override
  Future<void> saveLoggedBlock(LoggedBlock block) =>
      _dao.saveLoggedBlock(block.toRow(_dao.now()));

  @override
  Future<void> deleteLog(String id) => _dao.deleteLog(id);
}
