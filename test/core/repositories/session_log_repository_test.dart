import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/logging_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/plan_repository.dart';
import 'package:coach_app/core/repositories/session_log_repository.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/core/utils/date_range.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SessionLogRepository repository;

  final today = DateOnly(2026, 9, 7);
  final week = DateRange(start: today, end: today.addDays(6));
  final clock = clockAt(DateTime(2026, 9, 7, 18, 30));

  SessionLog log({
    String id = 'log1',
    DateOnly? date,
    SessionStatus status = SessionStatus.inProgress,
    bool started = true,
  }) => SessionLog(
    id: id,
    planId: 'p1',
    blockId: 'b1',
    sessionTemplateId: 't1',
    date: date ?? today,
    status: status,
    startedAt: started ? DateTime(2026, 9, 7, 18) : null,
    plannedSnapshot: '{"entries":[]}',
  );

  LoggedExercise loggedExercise(String id, {int orderIndex = 0}) =>
      LoggedExercise(
        id: id,
        sessionLogId: 'log1',
        exerciseId: 'x1',
        orderIndex: orderIndex,
      );

  LoggedSet loggedSet(String id, String exerciseId, {int? plannedReps = 5}) =>
      LoggedSet(
        id: id,
        loggedExerciseId: exerciseId,
        orderIndex: 0,
        kind: SetKind.weightReps,
        plannedWeight: 80,
        plannedReps: plannedReps,
      );

  setUp(() async {
    db = openTestDatabase();
    repository = DriftSessionLogRepository(LoggingDao(db, now: clock));

    final plans = DriftPlanRepository(
      PlanningDao(db, now: clock),
      ContentDao(db, now: clock),
      SchedulingDao(db, now: clock),
    );
    await plans.savePlan(
      const Plan(id: 'p1', name: 'Upper/Lower', type: PlanType.strength),
    );
    await plans.savePlan(
      const Plan(id: 'p2', name: 'Semi', type: PlanType.endurance),
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'x1',
            createdAt: DateTime(2026, 9, 7),
            updatedAt: DateTime(2026, 9, 7),
            name: 'Squat',
          ),
        );
  });

  tearDown(() => db.close());

  group('materialising a session', () {
    test('writes the log and its content in one commit', () async {
      await repository.createLog(
        log: log(),
        exercises: [loggedExercise('le1'), loggedExercise('le2')],
        setsByExercise: {
          'le1': [loggedSet('s1', 'le1'), loggedSet('s2', 'le1')],
          'le2': [loggedSet('s3', 'le2')],
        },
      );

      expect(
        (await repository.findLog('log1'))?.status,
        SessionStatus.inProgress,
      );
      expect(
        (await repository.watchLoggedExercises('log1').first).map((e) => e.id),
        ['le1', 'le2'],
      );
      expect((await repository.watchLoggedSets('le1').first).map((s) => s.id), [
        's1',
        's2',
      ]);
    });

    test('renumbers logged content with gaps', () async {
      await repository.createLog(
        log: log(),
        exercises: [
          loggedExercise('le1', orderIndex: 7),
          loggedExercise('le2', orderIndex: 3),
        ],
        setsByExercise: {
          'le1': [loggedSet('s1', 'le1'), loggedSet('s2', 'le1')],
        },
      );

      expect(
        (await repository.watchLoggedExercises('log1').first).map(
          (e) => e.orderIndex,
        ),
        [0, 100],
      );
      expect(
        (await repository.watchLoggedSets('le1').first).map(
          (s) => s.orderIndex,
        ),
        [0, 100],
      );
    });

    test('writes endurance blocks with their rounds', () async {
      await repository.createLog(
        log: log(),
        blocks: [
          const LoggedBlock(
            id: 'lb1',
            sessionLogId: 'log1',
            orderIndex: 0,
            roundIndex: 0,
            role: EnduranceBlockRole.work,
            measure: EnduranceMeasure.distance,
            targetValue: 400,
            intensityLabel: 'Z4',
          ),
          const LoggedBlock(
            id: 'lb2',
            sessionLogId: 'log1',
            orderIndex: 0,
            roundIndex: 1,
            role: EnduranceBlockRole.work,
            measure: EnduranceMeasure.distance,
            targetValue: 400,
            intensityLabel: 'Z4',
          ),
        ],
      );

      final blocks = await repository.watchLoggedBlocks('log1').first;
      expect(blocks.map((b) => b.roundIndex), [0, 1]);
      // The label is stored as text: deleting "Z4" two years from now must
      // not rewrite this session (PRD §4.3).
      expect(blocks.first.intensityLabel, 'Z4');
    });

    test('accepts a skipped log with no startedAt and no content', () async {
      await repository.createLog(
        log: log(status: SessionStatus.skipped, started: false),
      );

      final skipped = await repository.findLog('log1');
      expect(skipped?.status, SessionStatus.skipped);
      expect(skipped?.startedAt, isNull);
      expect(skipped?.plannedSnapshot, isNotNull);
    });

    test('rejects an unstarted log that is not a skip', () async {
      // A log with no startedAt and a status other than skipped describes a
      // session that was neither performed nor declined
      // (`docs/PLANNING.md` §2).
      await expectLater(
        repository.createLog(log: log(started: false)),
        throwsArgumentError,
      );
    });

    test('rejects a second log for the same plan on the same day', () async {
      await repository.createLog(log: log());

      // The engine keys logs by plan and date; a second one would silently
      // shadow the first.
      await expectLater(
        repository.createLog(log: log(id: 'log2')),
        throwsA(isA<DuplicateSessionLogException>()),
      );
    });

    test('allows the other plan type to log the same day', () async {
      await repository.createLog(log: log());

      await expectLater(
        repository.createLog(
          log: log(id: 'log2').copyWith(planId: 'p2', blockId: null),
        ),
        completes,
      );
    });

    test('a failed commit leaves no log behind', () async {
      await expectLater(
        repository.createLog(
          log: log(),
          exercises: [loggedExercise('le1').copyWith(exerciseId: 'ghost')],
          setsByExercise: const {},
        ),
        throwsA(isA<Exception>()),
      );

      expect(await repository.findLog('log1'), isNull);
    });
  });

  group('logging as the session runs', () {
    setUp(() async {
      await repository.createLog(
        log: log(),
        exercises: [loggedExercise('le1')],
        setsByExercise: {
          'le1': [loggedSet('s1', 'le1')],
        },
      );
    });

    test('persists a single set mutation', () async {
      final set = (await repository.watchLoggedSets('le1').first).single;

      await repository.saveLoggedSet(
        set.copyWith(actualWeight: 82.5, actualReps: 5, completed: true),
      );

      final saved = (await repository.watchLoggedSets('le1').first).single;
      expect(saved.actualWeight, 82.5);
      expect(saved.completed, isTrue);
    });

    test('adds a set to an exercise mid-session', () async {
      await repository.saveLoggedSet(
        loggedSet('s2', 'le1').copyWith(orderIndex: 100),
      );

      expect((await repository.watchLoggedSets('le1').first).map((s) => s.id), [
        's1',
        's2',
      ]);
    });

    test('marks an exercise skipped without touching the rest', () async {
      final exercise =
          (await repository.watchLoggedExercises('log1').first).single;

      await repository.saveLoggedExercise(exercise.copyWith(skipped: true));

      expect(
        (await repository.watchLoggedExercises('log1').first).single.skipped,
        isTrue,
      );
      expect(await repository.watchLoggedSets('le1').first, hasLength(1));
    });

    test('records an endurance block as it is performed', () async {
      await repository.saveLoggedBlock(
        const LoggedBlock(
          id: 'lb1',
          sessionLogId: 'log1',
          orderIndex: 0,
          roundIndex: 0,
          role: EnduranceBlockRole.work,
          measure: EnduranceMeasure.duration,
          targetValue: 600,
          actualDurationSeconds: 612,
          completed: true,
        ),
      );

      final block = (await repository.watchLoggedBlocks('log1').first).single;
      expect(block.actualDurationSeconds, 612);
    });

    test('completing the session stamps its status', () async {
      final open = (await repository.findLog('log1'))!;

      await repository.saveLog(
        open.copyWith(
          status: SessionStatus.completed,
          completedAt: DateTime(2026, 9, 7, 19, 15),
          totalDurationSeconds: 4500,
        ),
      );

      final finished = (await repository.findLog('log1'))!;
      expect(finished.status, SessionStatus.completed);
      expect(finished.totalDurationSeconds, 4500);
      // The snapshot is untouched by anything that happens afterwards.
      expect(finished.plannedSnapshot, '{"entries":[]}');
    });
  });

  group('reading history', () {
    test('reads the logs falling in a window, newest content intact', () async {
      await repository.createLog(log: log(date: today));
      await repository.createLog(
        log: log(id: 'log2', date: today.addDays(3)),
      );
      await repository.createLog(
        log: log(id: 'log3', date: today.addDays(30)),
      );

      final logs = await repository.watchLogs(week).first;
      expect(logs.map((l) => l.id), ['log1', 'log2']);
    });

    test('finds the log materialised for an occurrence', () async {
      await repository.createLog(log: log());

      final found = await repository.findLogForOccurrence(
        planId: 'p1',
        date: today,
      );
      expect(found?.id, 'log1');
      expect(
        await repository.findLogForOccurrence(
          planId: 'p1',
          date: today.addDays(1),
        ),
        isNull,
      );
    });

    test('deleting a log takes its content with it', () async {
      await repository.createLog(
        log: log(),
        exercises: [loggedExercise('le1')],
        setsByExercise: {
          'le1': [loggedSet('s1', 'le1')],
        },
      );

      await repository.deleteLog('log1');

      expect(await repository.findLog('log1'), isNull);
      expect(await repository.watchLoggedExercises('log1').first, isEmpty);
      expect(await repository.watchLoggedSets('le1').first, isEmpty);
      expect(await db.select(db.loggedSets).get(), hasLength(1));
    });
  });

  test('a duplicate log names the plan and the day', () {
    expect(
      DuplicateSessionLogException('p1', today).toString(),
      allOf(contains('p1'), contains('2026-09-07')),
    );
  });
}
