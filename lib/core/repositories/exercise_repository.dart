import 'package:coach_app/core/database/dao/exercise_dao.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/text_normalisation.dart';

/// Exercises: the stable identity per-exercise history aggregates on
/// (PRD §4.5).
///
/// There is no seeded catalogue and no browse screen in V1 — exercises come
/// into existence inline while a session is being built, which is why
/// [findOrCreateByName] is the method the editor actually calls.
abstract interface class ExerciseRepository {
  /// Every live exercise, ordered by name.
  Stream<List<Exercise>> watchAll();

  /// The autocomplete feed: live exercises whose name contains [query],
  /// ignoring case, accents and surrounding whitespace. A blank query
  /// matches everything.
  Stream<List<Exercise>> watchMatching(String query);

  Future<Exercise?> findById(String id);

  /// Inserts or updates [exercise] by its id.
  Future<void> save(Exercise exercise);

  /// The exercise named [name], creating it if no live one matches.
  ///
  /// Throws [ArgumentError] if [name] is blank.
  Future<Exercise> findOrCreateByName(String name);

  /// Soft-deletes the exercise. Logs referencing it stay readable.
  Future<void> delete(String id);
}

/// Drift-backed [ExerciseRepository].
class DriftExerciseRepository implements ExerciseRepository {
  const DriftExerciseRepository(this._dao);

  final ExerciseDao _dao;

  @override
  Stream<List<Exercise>> watchAll() => _dao.watchAll().map(
    (rows) => _sortedByName(rows.map((row) => row.toDomain())),
  );

  @override
  Stream<List<Exercise>> watchMatching(String query) {
    final key = foldForSearch(query);
    return watchAll().map(
      (exercises) => key.isEmpty
          ? exercises
          : exercises
                .where((e) => foldForSearch(e.name).contains(key))
                .toList(),
    );
  }

  @override
  Future<Exercise?> findById(String id) async =>
      (await _dao.findById(id))?.toDomain();

  @override
  Future<void> save(Exercise exercise) =>
      _dao.save(exercise.toRow(_dao.now()));

  @override
  Future<Exercise> findOrCreateByName(String name) async {
    final key = foldForSearch(name);
    if (key.isEmpty) {
      throw ArgumentError.value(name, 'name', 'An exercise needs a name');
    }
    for (final row in await _dao.getAll()) {
      if (foldForSearch(row.name) == key) return row.toDomain();
    }
    final created = Exercise(id: newId(), name: name.trim());
    await save(created);
    return created;
  }

  @override
  Future<void> delete(String id) => _dao.softDelete(id);

  /// Ordered on the folded name, so accented names land where a French
  /// reader looks for them rather than after `z`.
  List<Exercise> _sortedByName(Iterable<Exercise> exercises) =>
      exercises.toList()..sort(
        (a, b) => foldForSearch(a.name).compareTo(foldForSearch(b.name)),
      );
}
