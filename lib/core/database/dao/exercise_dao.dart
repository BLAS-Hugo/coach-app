import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:drift/drift.dart';

part 'exercise_dao.g.dart';

/// Reads and writes the `exercises` table.
///
/// Deliberately returns unordered rows: exercise names are French and
/// SQLite's collations are ASCII-only, so ordering and matching happen in
/// Dart over a folded key (see `foldForSearch`). Sorting "Élévations" after
/// "Squat" is exactly the bug that would produce.
@DriftAccessor(tables: [Exercises])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin, SyncableDao {
  ExerciseDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  Stream<List<ExerciseRow>> watchAll() => selectLive(exercises).watch();

  Future<List<ExerciseRow>> getAll() => selectLive(exercises).get();

  Future<ExerciseRow?> findById(String id) => findLiveById(exercises, id);

  Future<void> save(ExerciseRow row) => upsertRow(exercises, row);

  Future<void> softDelete(String id) => softDeleteRow(exercises, id);
}
