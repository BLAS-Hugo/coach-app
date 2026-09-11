import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/planning_tables.dart';
import 'package:drift/drift.dart';

part 'content_dao.g.dart';

/// The size of one template's content: what a one-line meta reads.
typedef ContentCounts = ({int exercises, int sets, int enduranceBlocks});

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

  /// How much live content each of [templateIds] holds.
  ///
  /// Counted in Dart over three small reads rather than in one grouped
  /// query: a plan holds a handful of templates, and the join a single
  /// statement needs — sets reach their template only through their entry —
  /// buys nothing at that size.
  Future<Map<String, ContentCounts>> loadContentCounts(
    List<String> templateIds,
  ) async {
    if (templateIds.isEmpty) return const {};
    final entries = await (selectLive(
      exerciseEntries,
    )..where((t) => t.sessionTemplateId.isIn(templateIds))).get();
    final templateOfEntry = {
      for (final entry in entries) entry.id: entry.sessionTemplateId,
    };
    final sets = templateOfEntry.isEmpty
        ? const <PlannedSetRow>[]
        : await (selectLive(
            plannedSets,
          )..where((t) => t.exerciseEntryId.isIn(templateOfEntry.keys))).get();
    final blocks = await (selectLive(
      enduranceBlocks,
    )..where((t) => t.sessionTemplateId.isIn(templateIds))).get();

    final exercises = <String, int>{};
    for (final entry in entries) {
      exercises.update(
        entry.sessionTemplateId,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final setCounts = <String, int>{};
    for (final set in sets) {
      setCounts.update(
        templateOfEntry[set.exerciseEntryId]!,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final blockCounts = <String, int>{};
    for (final block in blocks) {
      blockCounts.update(
        block.sessionTemplateId,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }

    return {
      for (final id in templateIds)
        id: (
          exercises: exercises[id] ?? 0,
          sets: setCounts[id] ?? 0,
          enduranceBlocks: blockCounts[id] ?? 0,
        ),
    };
  }

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

  Stream<List<IntensityLabelRow>> watchIntensityLabels() => (selectLive(
    intensityLabels,
  )..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).watch();

  Future<void> saveIntensityLabel(IntensityLabelRow row) =>
      upsertRow(intensityLabels, row);

  /// Deletes a label and clears it off the blocks that referenced it.
  ///
  /// Only *planned* blocks: a logged block carries the label as text, so
  /// history keeps reading "Z4" long after the label is gone (PRD §4.3).
  Future<void> deleteIntensityLabel(String id) => transaction(() async {
    final stamp = now();
    await (update(enduranceBlocks)
          ..where((t) => t.intensityLabelId.equals(id) & t.deletedAt.isNull()))
        .write(
          EnduranceBlocksCompanion(
            intensityLabelId: const Value(null),
            updatedAt: Value(stamp),
          ),
        );
    await softDeleteRow(intensityLabels, id);
  });

  /// Soft-deletes everything hanging off [templateIds].
  ///
  /// Called when a template or its whole plan is deleted: content left live
  /// under a deleted template is invisible to every screen but would come
  /// back the moment anything read that template by id.
  Future<void> deleteContentOfTemplates(Iterable<String> templateIds) {
    final ids = templateIds.toList();
    if (ids.isEmpty) return Future.value();
    return transaction(() async {
      await softDeleteWhere(
        plannedSets,
        (t) => t.exerciseEntryId.isInQuery(_entryIdsOfTemplates(ids)),
      );
      await softDeleteWhere(
        exerciseEntries,
        (t) => t.sessionTemplateId.isIn(ids),
      );
      await softDeleteWhere(
        enduranceBlocks,
        (t) => t.sessionTemplateId.isIn(ids),
      );
      await softDeleteWhere(repeatGroups, (t) => t.sessionTemplateId.isIn(ids));
    });
  }

  /// Every entry id of a template, deleted ones included.
  JoinedSelectStatement<$ExerciseEntriesTable, ExerciseEntryRow> _entryIdsOf(
    String templateId,
  ) => selectOnly(exerciseEntries)
    ..addColumns([exerciseEntries.id])
    ..where(exerciseEntries.sessionTemplateId.equals(templateId));

  JoinedSelectStatement<$ExerciseEntriesTable, ExerciseEntryRow>
  _entryIdsOfTemplates(List<String> templateIds) => selectOnly(exerciseEntries)
    ..addColumns([exerciseEntries.id])
    ..where(exerciseEntries.sessionTemplateId.isIn(templateIds));
}
