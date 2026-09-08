import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/plan_repository.dart';
import 'package:coach_app/core/repositories/session_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SessionContentRepository repository;

  final clock = clockAt(DateTime(2026, 9, 7, 10));

  ExerciseEntry entry(String id, {String exerciseId = 'x1'}) => ExerciseEntry(
    id: id,
    sessionTemplateId: 't1',
    exerciseId: exerciseId,
    orderIndex: 0,
  );

  PlannedSet plannedSet(String id, String entryId, {int reps = 5}) =>
      PlannedSet(
        id: id,
        exerciseEntryId: entryId,
        orderIndex: 0,
        kind: SetKind.weightReps,
        weight: 80,
        reps: reps,
      );

  EnduranceBlock enduranceBlock(
    String id, {
    String? repeatGroupId,
    String? intensityLabelId,
    EnduranceBlockRole role = EnduranceBlockRole.work,
  }) => EnduranceBlock(
    id: id,
    sessionTemplateId: 't1',
    orderIndex: 0,
    role: role,
    measure: EnduranceMeasure.distance,
    targetValue: 400,
    repeatGroupId: repeatGroupId,
    intensityLabelId: intensityLabelId,
  );

  setUp(() async {
    db = openTestDatabase();
    repository = DriftSessionContentRepository(ContentDao(db, now: clock));

    final plans = DriftPlanRepository(
      PlanningDao(db, now: clock),
      ContentDao(db, now: clock),
      SchedulingDao(db, now: clock),
    );
    await plans.savePlan(
      const Plan(id: 'p1', name: 'Upper/Lower', type: PlanType.strength),
    );
    await plans.saveTemplate(
      const SessionTemplate(id: 't1', planId: 'p1', name: 'Haut du corps'),
    );
    await plans.saveTemplate(
      const SessionTemplate(id: 't2', planId: 'p1', name: 'Bas du corps'),
    );
    for (final id in ['x1', 'x2']) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: id,
              createdAt: DateTime(2026, 9, 7),
              updatedAt: DateTime(2026, 9, 7),
              name: 'Exercice $id',
            ),
          );
    }
  });

  tearDown(() => db.close());

  group('strength content', () {
    test('writes entries and their planned sets in one commit', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [
          entry('e1'),
          entry('e2', exerciseId: 'x2'),
        ],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1'), plannedSet('s2', 'e1', reps: 3)],
          'e2': [plannedSet('s3', 'e2')],
        },
      );

      expect((await repository.watchEntries('t1').first).map((e) => e.id), [
        'e1',
        'e2',
      ]);
      expect(
        (await repository.watchPlannedSets('e1').first).map((s) => s.reps),
        [5, 3],
      );
    });

    test('renumbers orderIndex with gaps, in list order', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [
          entry('e1').copyWith(orderIndex: 900),
          entry('e2', exerciseId: 'x2').copyWith(orderIndex: 3),
        ],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1'), plannedSet('s2', 'e1')],
        },
      );

      // Gaps of 100 so a later drag-reorder rewrites one row instead of
      // renumbering the whole list (`docs/PLANNING.md` §2).
      expect(
        (await repository.watchEntries('t1').first).map((e) => e.orderIndex),
        [0, 100],
      );
      expect(
        (await repository.watchPlannedSets('e1').first).map(
          (s) => s.orderIndex,
        ),
        [0, 100],
      );
    });

    test('reordering the list reorders what is read back', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [
          entry('e1'),
          entry('e2', exerciseId: 'x2'),
        ],
        setsByEntry: const {},
      );

      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [
          entry('e2', exerciseId: 'x2'),
          entry('e1'),
        ],
        setsByEntry: const {},
      );

      expect((await repository.watchEntries('t1').first).map((e) => e.id), [
        'e2',
        'e1',
      ]);
    });

    test('drops an entry left out of the commit, and its sets', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [
          entry('e1'),
          entry('e2', exerciseId: 'x2'),
        ],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1')],
          'e2': [plannedSet('s2', 'e2')],
        },
      );

      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [entry('e1')],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1')],
        },
      );

      expect((await repository.watchEntries('t1').first).map((e) => e.id), [
        'e1',
      ]);
      expect(await repository.watchPlannedSets('e2').first, isEmpty);
      // Soft-deleted, like everything else in this database.
      expect(await db.select(db.plannedSets).get(), hasLength(2));
    });

    test('drops a set left out of the commit', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [entry('e1')],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1'), plannedSet('s2', 'e1')],
        },
      );

      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [entry('e1')],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1')],
        },
      );

      expect((await repository.watchPlannedSets('e1').first).map((s) => s.id), [
        's1',
      ]);
    });

    test('leaves another template untouched', () async {
      await repository.replaceStrengthContent(
        templateId: 't2',
        entries: [entry('e9').copyWith(sessionTemplateId: 't2')],
        setsByEntry: const {},
      );

      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [entry('e1')],
        setsByEntry: const {},
      );

      expect((await repository.watchEntries('t2').first).map((e) => e.id), [
        'e9',
      ]);
    });

    test('a failed commit changes nothing', () async {
      await repository.replaceStrengthContent(
        templateId: 't1',
        entries: [entry('e1')],
        setsByEntry: {
          'e1': [plannedSet('s1', 'e1')],
        },
      );

      // The second entry points at an exercise that does not exist. The
      // editor commits a whole session at once, so a half-written template
      // is the one outcome that must be impossible.
      await expectLater(
        repository.replaceStrengthContent(
          templateId: 't1',
          entries: [entry('e2', exerciseId: 'ghost')],
          setsByEntry: const {},
        ),
        throwsA(isA<Exception>()),
      );

      expect((await repository.watchEntries('t1').first).map((e) => e.id), [
        'e1',
      ]);
      expect((await repository.watchPlannedSets('e1').first).map((s) => s.id), [
        's1',
      ]);
    });
  });

  group('endurance content', () {
    test('writes repeat groups and blocks in one commit', () async {
      await repository.replaceEnduranceContent(
        templateId: 't1',
        repeatGroups: [
          const RepeatGroup(
            id: 'g1',
            sessionTemplateId: 't1',
            orderIndex: 0,
            repeatCount: 6,
          ),
        ],
        blocks: [
          enduranceBlock('b1', role: EnduranceBlockRole.warmup),
          enduranceBlock('b2', repeatGroupId: 'g1'),
          enduranceBlock(
            'b3',
            repeatGroupId: 'g1',
            role: EnduranceBlockRole.recovery,
          ),
        ],
      );

      final blocks = await repository.watchEnduranceBlocks('t1').first;
      expect(blocks.map((b) => b.id), ['b1', 'b2', 'b3']);
      expect(blocks.map((b) => b.orderIndex), [0, 100, 200]);
      expect(blocks[1].repeatGroupId, 'g1');
      expect(
        (await repository.watchRepeatGroups('t1').first).single.repeatCount,
        6,
      );
    });

    test('drops a repeat group and its blocks left out of a commit', () async {
      await repository.replaceEnduranceContent(
        templateId: 't1',
        repeatGroups: [
          const RepeatGroup(
            id: 'g1',
            sessionTemplateId: 't1',
            orderIndex: 0,
            repeatCount: 6,
          ),
        ],
        blocks: [enduranceBlock('b1', repeatGroupId: 'g1')],
      );

      await repository.replaceEnduranceContent(
        templateId: 't1',
        repeatGroups: const [],
        blocks: [enduranceBlock('b2')],
      );

      expect(await repository.watchRepeatGroups('t1').first, isEmpty);
      expect(
        (await repository.watchEnduranceBlocks('t1').first).map((b) => b.id),
        ['b2'],
      );
    });
  });

  group('intensity labels', () {
    test('reads labels back in their configured order', () async {
      await repository.saveIntensityLabel(
        const IntensityLabel(id: 'l1', label: 'Z4', orderIndex: 100),
      );
      await repository.saveIntensityLabel(
        const IntensityLabel(id: 'l2', label: 'Z2', orderIndex: 0),
      );

      expect(
        (await repository.watchIntensityLabels().first).map((l) => l.label),
        ['Z2', 'Z4'],
      );
    });

    test('deleting a label clears it off the blocks using it', () async {
      await repository.saveIntensityLabel(
        const IntensityLabel(id: 'l1', label: 'Z4', orderIndex: 0),
      );
      await repository.replaceEnduranceContent(
        templateId: 't1',
        repeatGroups: const [],
        blocks: [enduranceBlock('b1', intensityLabelId: 'l1')],
      );

      await repository.deleteIntensityLabel('l1');

      // The block survives without its label; a logged block keeps the text
      // it was performed with, so history still reads "Z4" (PRD §4.3).
      final block = (await repository.watchEnduranceBlocks('t1').first).single;
      expect(block.intensityLabelId, isNull);
      expect(await repository.watchIntensityLabels().first, isEmpty);
    });
  });
}
