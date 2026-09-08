import 'dart:async';

import 'package:coach_app/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// The column-name constants of `SyncableTable`, in the snake_case drift
/// generates them as.
const _idColumn = 'id';
const _createdAtColumn = 'created_at';
const _updatedAtColumn = 'updated_at';
const _deletedAtColumn = 'deleted_at';

/// Shared reads and writes for the tables carrying the sync-ready baseline
/// of PRD §8 — every table in this database.
///
/// The helpers are generic over the table because the three rules they
/// enforce are the same everywhere and must not be re-decided per DAO:
///
/// - a live read never sees a soft-deleted row,
/// - a write stamps `updatedAt` and preserves the original `createdAt`,
/// - a delete is an `UPDATE`, never a `DELETE` — a plan's session logs stay
///   readable in history forever (PRD §4.1).
///
/// They reach for columns by name rather than through the generated table
/// classes because there is no common supertype expressing "has the four
/// baseline columns"; the constants above are the contract, and
/// `SyncableTable` is what keeps it true.
mixin SyncableDao on DatabaseAccessor<AppDatabase> {
  /// The clock writes are stamped from. Injected so a test can assert what
  /// a write recorded instead of racing the wall clock.
  DateTime Function() get now;

  /// A select over [table] restricted to rows that are not soft-deleted.
  SimpleSelectStatement<T, R> selectLive<T extends Table, R>(
    TableInfo<T, R> table,
  ) => select(table)..where((_) => _deletedAt(table).isNull());

  /// The live row with this id, or null if it never existed or was deleted.
  Future<R?> findLiveById<T extends Table, R>(
    TableInfo<T, R> table,
    String id,
  ) => (selectLive(
    table,
  )..where((_) => _id(table).equals(id))).getSingleOrNull();

  /// Watches the live rows matching [filter].
  Stream<List<R>> watchLiveWhere<T extends Table, R>(
    TableInfo<T, R> table,
    Expression<bool> Function(T table) filter,
  ) => (selectLive(table)..where(filter)).watch();

  /// Inserts [row], or updates every column but `createdAt` if its id is
  /// already taken.
  ///
  /// Callers hand over a row stamped with [now] for both timestamps; the
  /// conflict clause then drops `createdAt`, so an update cannot rewrite
  /// when the row first appeared. This is one round trip — reading the old
  /// row first to preserve its `createdAt` would be two, and would race.
  Future<void> upsertRow<T extends Table, R>(
    TableInfo<T, R> table,
    Insertable<R> row,
  ) async {
    final values = row.toColumns(false);
    final onConflict = Map.of(values)..remove(_createdAtColumn);
    await into(table).insert(
      RawValuesInsertable<R>(values),
      onConflict: DoUpdate<T, R>((_) => RawValuesInsertable<R>(onConflict)),
    );
  }

  /// Inserts or updates every row of [rows] in one statement per row.
  Future<void> upsertRows<T extends Table, R>(
    TableInfo<T, R> table,
    Iterable<Insertable<R>> rows,
  ) async {
    for (final row in rows) {
      await upsertRow(table, row);
    }
  }

  /// Soft-deletes the row with this id. Returns the number of rows changed,
  /// which is 0 when the row was already deleted.
  Future<int> softDeleteRow<T extends Table, R>(
    TableInfo<T, R> table,
    String id,
  ) => softDeleteWhere(table, (_) => _id(table).equals(id));

  /// Soft-deletes every live row matching [filter].
  ///
  /// Already-deleted rows are left untouched so a cascade cannot overwrite
  /// the moment an earlier delete happened.
  Future<int> softDeleteWhere<T extends Table, R>(
    TableInfo<T, R> table,
    Expression<bool> Function(T table) filter,
  ) {
    final stamp = now();
    return (update(
      table,
    )..where((t) => filter(t) & _deletedAt(table).isNull())).write(
      RawValuesInsertable<R>({
        _deletedAtColumn: Variable<DateTime>(stamp),
        _updatedAtColumn: Variable<DateTime>(stamp),
      }),
    );
  }

  /// Re-runs [read] whenever any of [tables] changes, beginning with one
  /// immediate read.
  ///
  /// For a value assembled from several tables at once. Listening to the
  /// database's update stream keeps it one trigger, one read and one
  /// emission per change, where combining a query stream per table would
  /// race and emit partial states in between. The subscription opens
  /// **before** the first read, because a write landing between the two
  /// would otherwise never reach a listener.
  Stream<T> watchRecomputed<T>(
    List<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() read,
  ) {
    final updates = attachedDatabase.tableUpdates(
      TableUpdateQuery.onAllTables(tables),
    );

    late StreamController<T> controller;
    StreamSubscription<void>? subscription;
    var reading = false;
    var stale = false;

    Future<void> reload() async {
      // A write arriving mid-read marks the result stale rather than
      // starting a second read, so a burst collapses into one extra pass
      // instead of a queue of them.
      if (reading) {
        stale = true;
        return;
      }
      reading = true;
      do {
        stale = false;
        try {
          final value = await read();
          if (controller.isClosed) break;
          controller.add(value);
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      } while (stale);
      reading = false;
    }

    controller = StreamController<T>(
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

  /// Soft-deletes every live row matching [filter] whose id is not in
  /// [keep].
  ///
  /// This is the delete half of a whole-collection commit: the caller
  /// upserts the rows it wants, then retires whatever it did not mention.
  Future<int> softDeleteMissing<T extends Table, R>(
    TableInfo<T, R> table,
    Expression<bool> Function(T table) filter,
    Iterable<String> keep,
  ) {
    final kept = keep.toList();
    return softDeleteWhere(
      table,
      (t) => kept.isEmpty ? filter(t) : filter(t) & _id(table).isNotIn(kept),
    );
  }

  GeneratedColumn<String> _id(
    ResultSetImplementation<dynamic, dynamic> table,
  ) => table.columnsByName[_idColumn]! as GeneratedColumn<String>;

  GeneratedColumn<DateTime> _deletedAt(
    ResultSetImplementation<dynamic, dynamic> table,
  ) => table.columnsByName[_deletedAtColumn]! as GeneratedColumn<DateTime>;
}
