import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/scheduling/occurrence_engine.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';

/// Thrown when a move would put two sessions of the same plan type on one
/// day (`docs/PLANNING.md` §4).
class OccurrenceCollisionException implements Exception {
  const OccurrenceCollisionException(this.date, this.type);

  final DateOnly date;
  final PlanType type;

  @override
  String toString() => 'A ${type.name} session already falls on $date';
}

/// The scheduling view of the database: what falls on which day, and the
/// deviations that bend the weekly template.
abstract interface class ScheduleRepository {
  /// Every occurrence in [range], recomputed whenever anything it depends
  /// on changes.
  Stream<List<SessionOccurrence>> watchOccurrences(DateRange range);

  Future<List<SessionOccurrence>> occurrencesIn(DateRange range);

  Stream<List<WeekOverride>> watchOverrides(String blockId);

  Future<void> setOverride(WeekOverride override);

  Future<void> clearOverride({
    required String blockId,
    required int weekIndex,
    required int weekday,
  });

  Stream<List<OccurrenceMove>> watchMoves(String blockId);

  /// Reschedules the occurrence of [blockId] on [from] to [to].
  ///
  /// Throws [OccurrenceCollisionException] if the target day already holds a
  /// session of the same plan type.
  Future<void> moveOccurrence({
    required String blockId,
    required DateOnly from,
    required DateOnly to,
  });

  Future<void> cancelMove({required String blockId, required DateOnly date});
}

/// Drift-backed [ScheduleRepository].
///
/// The only place the occurrence engine is fed. Everything it needs is read
/// in one pass and handed over whole, so the engine itself stays pure and
/// keeps its exhaustive unit tests (`docs/PLANNING.md` §4).
class DriftScheduleRepository implements ScheduleRepository {
  const DriftScheduleRepository(this._dao);

  final SchedulingDao _dao;

  @override
  Stream<List<SessionOccurrence>> watchOccurrences(DateRange range) =>
      _dao.watchSources(range).map((sources) => _compute(sources, range));

  @override
  Future<List<SessionOccurrence>> occurrencesIn(DateRange range) async =>
      _compute(await _dao.loadSources(range), range);

  @override
  Stream<List<WeekOverride>> watchOverrides(String blockId) => _dao
      .watchOverrides(blockId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> setOverride(WeekOverride override) =>
      _dao.setOverride(override.toRow(_dao.now()));

  @override
  Future<void> clearOverride({
    required String blockId,
    required int weekIndex,
    required int weekday,
  }) => _dao.clearOverride(
    blockId: blockId,
    weekIndex: weekIndex,
    weekday: weekday,
  );

  @override
  Stream<List<OccurrenceMove>> watchMoves(String blockId) => _dao
      .watchMoves(blockId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> moveOccurrence({
    required String blockId,
    required DateOnly from,
    required DateOnly to,
  }) async {
    final existing = await _dao.findMove(blockId: blockId, date: from);
    if (existing != null && existing.targetDate == to) return;

    final block = await _dao.findBlock(blockId);
    if (block == null) return;
    final plan = await _dao.findPlan(block.planId);
    if (plan == null) return;

    // The occurrence being moved still sits on its source date, so anything
    // of the same type already on the target is a real conflict. Checked
    // here rather than in the engine, which computes a window and has no
    // way to tell the user which session is in the way.
    final onTarget = await occurrencesIn(DateRange(start: to, end: to));
    if (onTarget.any((occurrence) => occurrence.type == plan.type)) {
      throw OccurrenceCollisionException(to, plan.type);
    }

    await _dao.setMove(
      OccurrenceMove(
        id: existing?.id ?? newId(),
        blockId: blockId,
        date: from,
        targetDate: to,
      ).toRow(_dao.now()),
    );
  }

  @override
  Future<void> cancelMove({
    required String blockId,
    required DateOnly date,
  }) => _dao.clearMove(blockId: blockId, date: date);

  List<SessionOccurrence> _compute(
    SchedulingSources sources,
    DateRange range,
  ) => OccurrenceEngine.computeOccurrences(
    input: SchedulingInput(
      plans: [for (final row in sources.plans) row.toDomain()],
      blocksByPlan: _groupBy(
        sources.blocks.map((row) => row.toDomain()),
        (block) => block.planId,
      ),
      slotsByBlock: _groupBy(
        sources.slots.map((row) => row.toDomain()),
        (slot) => slot.blockId,
      ),
      overridesByBlock: _groupBy(
        sources.overrides.map((row) => row.toDomain()),
        (override) => override.blockId,
      ),
      movesByBlock: _groupBy(
        sources.moves.map((row) => row.toDomain()),
        (move) => move.blockId,
      ),
      logs: [for (final row in sources.logs) row.toDomain()],
      today: DateOnly.today(clock: _dao.now),
    ),
    range: range,
  );

  Map<String, List<T>> _groupBy<T>(
    Iterable<T> items,
    String Function(T) key,
  ) {
    final grouped = <String, List<T>>{};
    for (final item in items) {
      (grouped[key(item)] ??= <T>[]).add(item);
    }
    return grouped;
  }
}
