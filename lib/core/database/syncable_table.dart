import 'package:drift/drift.dart';

/// The four columns every table in this database carries.
///
/// This is the sync-ready baseline of PRD §8 and it is **non-negotiable**:
/// retrofitting it onto a populated database later is the expensive path,
/// and there is no cloud backup to fall back on if that goes wrong.
///
/// - [id] is a UUID v7 rather than an autoincrementing integer. v7 sorts
///   chronologically, so ids are debuggable and remain unique if rows are
///   ever merged from another device. The column carries no length check:
///   "36 characters" is a weak proxy for "is a UUID", and the invariant is
///   better held at the single place ids are minted — see `newId()` in
///   `id_generator.dart`.
/// - [deletedAt] means rows are **soft-deleted**. Nothing in this app ever
///   issues a `DELETE`: a deleted plan must keep its session logs readable
///   in history forever (PRD §4.1).
///
/// Every query that reads live data must therefore filter on
/// `deletedAt IS NULL`. The DAOs do this centrally so no call site has to
/// remember.
mixin SyncableTable on Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Non-null once the row is soft-deleted.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
