import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';

/// The content of a session template.
///
/// Writes are whole-template commits rather than per-field saves: the plan
/// editor holds a draft aggregate in bloc state and commits it in one
/// transaction (`docs/PLANNING.md` §5), which is what keeps the database out
/// of the interaction loop and makes a half-written session impossible.
abstract interface class SessionContentRepository {
  Stream<List<ExerciseEntry>> watchEntries(String templateId);

  Stream<List<PlannedSet>> watchPlannedSets(String entryId);

  /// Makes [entries] and [setsByEntry] the entire strength content of the
  /// template, in one transaction.
  Future<void> replaceStrengthContent({
    required String templateId,
    required List<ExerciseEntry> entries,
    required Map<String, List<PlannedSet>> setsByEntry,
  });

  Stream<List<EnduranceBlock>> watchEnduranceBlocks(String templateId);

  Stream<List<RepeatGroup>> watchRepeatGroups(String templateId);

  /// Makes [repeatGroups] and [blocks] the entire endurance content of the
  /// template, in one transaction.
  Future<void> replaceEnduranceContent({
    required String templateId,
    required List<RepeatGroup> repeatGroups,
    required List<EnduranceBlock> blocks,
  });

  Stream<List<IntensityLabel>> watchIntensityLabels();

  Future<void> saveIntensityLabel(IntensityLabel label);

  Future<void> deleteIntensityLabel(String id);
}

/// Drift-backed [SessionContentRepository].
class DriftSessionContentRepository implements SessionContentRepository {
  const DriftSessionContentRepository(this._dao);

  /// The gap left between consecutive `orderIndex` values.
  ///
  /// Wide enough that a later drag-reorder can slot a row between two
  /// neighbours by writing one row instead of renumbering the list
  /// (`docs/PLANNING.md` §2). A whole-content commit renormalises them back
  /// to multiples of this.
  static const _orderGap = 100;

  final ContentDao _dao;

  @override
  Stream<List<ExerciseEntry>> watchEntries(String templateId) => _dao
      .watchEntries(templateId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Stream<List<PlannedSet>> watchPlannedSets(String entryId) => _dao
      .watchPlannedSets(entryId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> replaceStrengthContent({
    required String templateId,
    required List<ExerciseEntry> entries,
    required Map<String, List<PlannedSet>> setsByEntry,
  }) {
    final at = _dao.now();
    final entryRows = [
      for (final (index, entry) in entries.indexed)
        entry
            .copyWith(
              sessionTemplateId: templateId,
              orderIndex: index * _orderGap,
            )
            .toRow(at),
    ];
    // Sets are collected through the entry list rather than through the map
    // keys, so a set left behind under a removed entry cannot resurrect it.
    final setRows = [
      for (final entry in entries)
        for (final (index, set) in (setsByEntry[entry.id] ?? const []).indexed)
          set
              .copyWith(
                exerciseEntryId: entry.id,
                orderIndex: index * _orderGap,
              )
              .toRow(at),
    ];

    return _dao.replaceStrengthContent(
      templateId: templateId,
      entries: entryRows,
      sets: setRows,
    );
  }

  @override
  Stream<List<EnduranceBlock>> watchEnduranceBlocks(String templateId) => _dao
      .watchEnduranceBlocks(templateId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Stream<List<RepeatGroup>> watchRepeatGroups(String templateId) => _dao
      .watchRepeatGroups(templateId)
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> replaceEnduranceContent({
    required String templateId,
    required List<RepeatGroup> repeatGroups,
    required List<EnduranceBlock> blocks,
  }) {
    final at = _dao.now();
    return _dao.replaceEnduranceContent(
      templateId: templateId,
      groups: [
        for (final (index, group) in repeatGroups.indexed)
          group
              .copyWith(
                sessionTemplateId: templateId,
                orderIndex: index * _orderGap,
              )
              .toRow(at),
      ],
      blocks: [
        for (final (index, block) in blocks.indexed)
          block
              .copyWith(
                sessionTemplateId: templateId,
                orderIndex: index * _orderGap,
              )
              .toRow(at),
      ],
    );
  }

  @override
  Stream<List<IntensityLabel>> watchIntensityLabels() => _dao
      .watchIntensityLabels()
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> saveIntensityLabel(IntensityLabel label) =>
      _dao.saveIntensityLabel(label.toRow(_dao.now()));

  @override
  Future<void> deleteIntensityLabel(String id) =>
      _dao.deleteIntensityLabel(id);
}
