import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:drift/drift.dart';

part 'content_dao.g.dart';

/// The content of session templates: strength entries and their planned
/// sets, endurance blocks and their repeat groups, and the intensity labels
/// those blocks point at.
@DriftAccessor(
  tables: [
    ExerciseEntries,
    PlannedSets,
    RepeatGroups,
    EnduranceBlocks,
    IntensityLabels,
  ],
)
class ContentDao extends DatabaseAccessor<AppDatabase>
    with _$ContentDaoMixin, SyncableDao {
  ContentDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  // --- strength ----------------------------------------------------------

  Stream<List<ExerciseEntryRow>> watchEntries(String templateId) =>
      (selectLive(exerciseEntries)
            ..where((t) => t.sessionTemplateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Stream<List<PlannedSetRow>> watchPlannedSets(String entryId) =>
      (selectLive(plannedSets)
            ..where((t) => t.exerciseEntryId.equals(entryId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  /// Makes [entries] and [sets] the entire strength content of the template.
  ///
  /// One transaction: the plan editor commits a whole session at once, so
  /// either every row lands or none does.
  Future<void> replaceStrengthContent({
    required String templateId,
    required List<ExerciseEntryRow> entries,
    required List<PlannedSetRow> sets,
  }) => transaction(() async {
    await upsertRows(exerciseEntries, entries);
    await upsertRows(plannedSets, sets);
    await softDeleteMissing(
      exerciseEntries,
      (t) => t.sessionTemplateId.equals(templateId),
      entries.map((row) => row.id),
    );
    // Reached through the template's entries, deleted ones included, so the
    // sets of an entry retired in this same commit go with it.
    await softDeleteMissing(
      plannedSets,
      (t) => t.exerciseEntryId.isInQuery(_entryIdsOf(templateId)),
      sets.map((row) => row.id),
    );
  });

  // --- endurance ---------------------------------------------------------

  Stream<List<EnduranceBlockRow>> watchEnduranceBlocks(String templateId) =>
      (selectLive(enduranceBlocks)
            ..where((t) => t.sessionTemplateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Stream<List<RepeatGroupRow>> watchRepeatGroups(String templateId) =>
      (selectLive(repeatGroups)
            ..where((t) => t.sessionTemplateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Future<void> replaceEnduranceContent({
    required String templateId,
    required List<RepeatGroupRow> groups,
    required List<EnduranceBlockRow> blocks,
  }) => transaction(() async {
    // Groups first: a block's `repeatGroupId` is a foreign key.
    await upsertRows(repeatGroups, groups);
    await upsertRows(enduranceBlocks, blocks);
    await softDeleteMissing(
      enduranceBlocks,
      (t) => t.sessionTemplateId.equals(templateId),
      blocks.map((row) => row.id),
    );
    await softDeleteMissing(
      repeatGroups,
      (t) => t.sessionTemplateId.equals(templateId),
      groups.map((row) => row.id),
    );
  });

  // --- intensity labels --------------------------------------------------

  Stream<List<IntensityLabelRow>> watchIntensityLabels() =>
      (selectLive(intensityLabels)
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Future<void> saveIntensityLabel(IntensityLabelRow row) =>
      upsertRow(intensityLabels, row);

  /// Deletes a label and clears it off the blocks that referenced it.
  ///
  /// Only *planned* blocks: a logged block carries the label as text, so
  /// history keeps reading "Z4" long after the label is gone (PRD §4.3).
  Future<void> deleteIntensityLabel(String id) => transaction(() async {
    final stamp = now();
    await (update(enduranceBlocks)..where(
          (t) => t.intensityLabelId.equals(id) & t.deletedAt.isNull(),
        ))
        .write(
          EnduranceBlocksCompanion(
            intensityLabelId: const Value(null),
            updatedAt: Value(stamp),
          ),
        );
    await softDeleteRow(intensityLabels, id);
  });

  /// Every entry id of a template, deleted ones included.
  JoinedSelectStatement<$ExerciseEntriesTable, ExerciseEntryRow> _entryIdsOf(
    String templateId,
  ) =>
      selectOnly(exerciseEntries)
        ..addColumns([exerciseEntries.id])
        ..where(exerciseEntries.sessionTemplateId.equals(templateId));
}
