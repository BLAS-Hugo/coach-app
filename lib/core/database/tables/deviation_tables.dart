import 'package:coach_app/core/database/converters.dart';
import 'package:coach_app/core/database/syncable_table.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:drift/drift.dart';

/// A per-week deviation from a block's weekly template: a deload or a swap.
class WeekOverrides extends Table with SyncableTable {
  TextColumn get blockId => text().references(TrainingBlocks, #id)();

  /// 0-based from the block's start date. Week 0 may be a partial week.
  IntColumn get weekIndex => integer()();

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  IntColumn get weekday => integer()();

  IntColumn get action => intEnum<WeekOverrideAction>()();

  TextColumn get replacementSessionTemplateId =>
      text().nullable().references(SessionTemplates, #id)();

  /// `0.8` is the −20 % deload of PRD §6.3.
  RealColumn get loadMultiplier => real().nullable()();
}

/// A single occurrence rescheduled to another date.
///
/// There is deliberately no skip variant: a skip is a session log with
/// status `skipped`, because skipping freezes a snapshot exactly as
/// starting does (PRD §5.2). One representation means the two paths can
/// never disagree.
class OccurrenceMoves extends Table with SyncableTable {
  TextColumn get blockId => text().references(TrainingBlocks, #id)();

  IntColumn get date => integer().map(const DateOnlyConverter())();

  IntColumn get targetDate => integer().map(const DateOnlyConverter())();
}
