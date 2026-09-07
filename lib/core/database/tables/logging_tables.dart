import 'package:coach_app/core/database/converters.dart';
import 'package:coach_app/core/database/syncable_table.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:drift/drift.dart';

/// The record created when the user starts — or skips — an occurrence.
///
/// Logs are **snapshots**. Once written, no edit to the plan ever touches
/// one. [blockId] and [sessionTemplateId] are nullable soft references
/// rather than enforced ones so a log stays readable after its template is
/// soft-deleted.
///
/// [startedAt] is null exactly when [status] is `skipped`: skipping
/// materialises the snapshot without performing anything.
class SessionLogs extends Table with SyncableTable {
  TextColumn get planId => text().references(Plans, #id)();

  TextColumn get blockId => text().nullable()();

  TextColumn get sessionTemplateId => text().nullable()();

  IntColumn get date => integer().map(const DateOnlyConverter())();

  IntColumn get status => intEnum<SessionStatus>()();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get totalDurationSeconds => integer().nullable()();

  TextColumn get notes => text().nullable()();

  /// The full planned content at materialisation time, as JSON.
  ///
  /// Deliberately redundant with the `logged_*` tables: those are what
  /// history queries read, this is the escape hatch for rendering a past
  /// session exactly as it was structured, including the superset and
  /// repeat grouping the relational tables flatten.
  TextColumn get plannedSnapshot => text().nullable()();
}

/// One exercise as performed, inside a session log.
class LoggedExercises extends Table with SyncableTable {
  TextColumn get sessionLogId => text().references(SessionLogs, #id)();

  TextColumn get exerciseId => text().references(Exercises, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get supersetGroup => integer().nullable()();

  BoolColumn get skipped => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();
}

/// One set as performed, carrying both what was planned and what happened.
///
/// The planned values are copied in rather than joined to, because the
/// planned set they came from may be edited or soft-deleted later. This is
/// what makes the `PRÉVU` / `RÉALISÉ` comparison on design screen 2c stable.
class LoggedSets extends Table with SyncableTable {
  TextColumn get loggedExerciseId => text().references(LoggedExercises, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get kind => intEnum<SetKind>()();

  RealColumn get plannedWeight => real().nullable()();

  IntColumn get plannedReps => integer().nullable()();

  IntColumn get plannedDurationSeconds => integer().nullable()();

  RealColumn get plannedIntensity => real().nullable()();

  RealColumn get actualWeight => real().nullable()();

  IntColumn get actualReps => integer().nullable()();

  IntColumn get actualDurationSeconds => integer().nullable()();

  RealColumn get actualIntensity => real().nullable()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// One endurance block as performed.
///
/// [roundIndex] flattens repeat groups: round 2 of a `6 × 400 m` group is
/// its own row.
class LoggedBlocks extends Table with SyncableTable {
  TextColumn get sessionLogId => text().references(SessionLogs, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get roundIndex => integer()();

  IntColumn get role => intEnum<EnduranceBlockRole>()();

  IntColumn get measure => intEnum<EnduranceMeasure>()();

  IntColumn get targetValue => integer()();

  /// Denormalised text on purpose: if the user deletes the "Z4" label two
  /// years from now, old logs must still read "Z4".
  TextColumn get intensityLabel => text().nullable()();

  IntColumn get actualDurationSeconds => integer().nullable()();

  IntColumn get actualDistanceMeters => integer().nullable()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// User preferences. Exactly one row.
class AppSettingsRows extends Table with SyncableTable {
  IntColumn get unitWeight => intEnum<WeightUnit>()();

  IntColumn get unitDistance => intEnum<DistanceUnit>()();

  IntColumn get intensityScale => intEnum<IntensityScale>()();

  IntColumn get defaultRestSeconds => integer()();

  BoolColumn get audioCues => boolean()();

  BoolColumn get vibration => boolean()();

  IntColumn get themeMode => intEnum<AppThemeMode>()();
}
