import 'package:coach_app/core/database/converters.dart';
import 'package:coach_app/core/database/syncable_table.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:drift/drift.dart';

/// A named movement with a stable identity, so history aggregates across
/// plans and blocks (PRD §3).
class Exercises extends Table with SyncableTable {
  TextColumn get name => text()();

  TextColumn get muscleGroup => text().nullable()();

  TextColumn get notes => text().nullable()();
}

/// A training program. Carries no dates — its blocks do.
class Plans extends Table with SyncableTable {
  TextColumn get name => text()();

  IntColumn get type => intEnum<PlanType>()();

  TextColumn get notes => text().nullable()();
}

/// One mesocycle within a plan (PRD §3).
///
/// [endDate] is set only when the user stops a block early; otherwise the
/// end follows from [startDate] and [durationWeeks]. Both null means the
/// block is ongoing. The derivation lives in the domain model, not here, so
/// there is one implementation of it.
class TrainingBlocks extends Table with SyncableTable {
  TextColumn get planId => text().references(Plans, #id)();

  TextColumn get name => text()();

  IntColumn get orderIndex => integer()();

  IntColumn get startDate => integer().map(const DateOnlyConverter())();

  IntColumn get durationWeeks => integer().nullable()();

  IntColumn get endDate => integer().nullable().map(
    const NullAwareTypeConverter.wrap(
      DateOnlyConverter(),
    ),
  )();

  TextColumn get notes => text().nullable()();
}

/// A named workout belonging to a plan, reusable across its blocks.
class SessionTemplates extends Table with SyncableTable {
  TextColumn get planId => text().references(Plans, #id)();

  TextColumn get name => text()();

  TextColumn get notes => text().nullable()();
}

/// One weekday of a block's weekly template.
///
/// The partial unique index is what enforces "at most one session per
/// weekday per block" while still allowing a soft-deleted row to sit
/// alongside its replacement. A plain `uniqueKeys` cannot express the
/// `deletedAt IS NULL` condition, so the index is declared as raw SQL.
@TableIndex.sql('''
  CREATE UNIQUE INDEX weekly_slots_one_per_weekday
  ON weekly_slots (block_id, weekday)
  WHERE deleted_at IS NULL;
''')
class WeeklySlots extends Table with SyncableTable {
  TextColumn get blockId => text().references(TrainingBlocks, #id)();

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  IntColumn get weekday => integer()();

  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();
}

/// One exercise within a strength session template, with its planned sets
/// hanging off it.
///
/// [supersetGroup] models supersets as groups-of-one by default (PRD §4.4),
/// so the runner has round-based logic before M7 adds the grouping UI.
class ExerciseEntries extends Table with SyncableTable {
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();

  TextColumn get exerciseId => text().references(Exercises, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get supersetGroup => integer().nullable()();

  IntColumn get restSeconds => integer().nullable()();

  TextColumn get notes => text().nullable()();
}

/// One planned work set. [kind] decides which of the value columns mean
/// anything.
class PlannedSets extends Table with SyncableTable {
  TextColumn get exerciseEntryId => text().references(ExerciseEntries, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get kind => intEnum<SetKind>()();

  /// Kilograms. Unit preference is a display concern only.
  RealColumn get weight => real().nullable()();

  IntColumn get reps => integer().nullable()();

  IntColumn get durationSeconds => integer().nullable()();

  /// RPE or RIR; which one is shown is a global setting.
  RealColumn get targetIntensity => real().nullable()();
}

/// An ordered subset of endurance blocks repeated [repeatCount] times, so
/// "6 × (400 m / 90 s)" is one group of two blocks rather than twelve rows.
class RepeatGroups extends Table with SyncableTable {
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get repeatCount => integer()();
}

/// A user-managed intensity label, e.g. `Z4`.
class IntensityLabels extends Table with SyncableTable {
  TextColumn get label => text()();

  IntColumn get orderIndex => integer()();
}

/// One segment of an endurance session: warmup, work, recovery or cooldown.
///
/// Not to be confused with a [TrainingBlocks] row, which is a mesocycle.
class EnduranceBlocks extends Table with SyncableTable {
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();

  TextColumn get repeatGroupId =>
      text().nullable().references(RepeatGroups, #id)();

  IntColumn get orderIndex => integer()();

  IntColumn get role => intEnum<EnduranceBlockRole>()();

  IntColumn get measure => intEnum<EnduranceMeasure>()();

  /// Seconds for a duration block, metres for a distance one.
  IntColumn get targetValue => integer()();

  TextColumn get intensityLabelId =>
      text().nullable().references(IntensityLabels, #id)();

  TextColumn get notes => text().nullable()();
}
