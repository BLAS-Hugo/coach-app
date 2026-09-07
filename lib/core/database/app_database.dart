import 'package:coach_app/core/database/converters.dart';
import 'package:coach_app/core/database/tables/deviation_tables.dart';
import 'package:coach_app/core/database/tables/logging_tables.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
// Imported for the generated part file: a part shares its library's scope,
// and the generated companions and row classes are typed in these.
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The local SQLite database. There is no server and never will be.
///
/// Foreign keys are enabled explicitly — SQLite leaves them off per
/// connection by default, so without this the `references` declarations on
/// the tables would document intent without enforcing anything.
@DriftDatabase(
  tables: [
    Exercises,
    Plans,
    TrainingBlocks,
    SessionTemplates,
    WeeklySlots,
    ExerciseEntries,
    PlannedSets,
    RepeatGroups,
    IntensityLabels,
    EnduranceBlocks,
    WeekOverrides,
    OccurrenceMoves,
    SessionLogs,
    LoggedExercises,
    LoggedSets,
    LoggedBlocks,
    AppSettingsRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'coach_app'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Stepwise migrations land here as the schema versions. There is
      // deliberately **no `deleteAndRecreate` fallback**: the app has no
      // cloud backup, so wiping the database on a failed migration
      // destroys the user's entire training history. A migration that
      // cannot proceed must fail loudly instead.
      throw StateError(
        'No migration from schema v$from to v$to. '
        'Add an explicit step rather than recreating the database.',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
