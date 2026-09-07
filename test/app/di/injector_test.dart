import 'package:coach_app/app/di/injector.dart';
import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  group('configureDependencies', () {
    tearDown(resetDependencies);

    test('registers the graph', () async {
      await configureDependencies(database: openTestDatabase());

      expect(getIt.isRegistered<AppDatabase>(), isTrue);
      expect(getIt.isRegistered<PlanRepository>(), isTrue);
    });

    test('is safe to run again after a reset', () async {
      await configureDependencies(database: openTestDatabase());
      await resetDependencies();
      await expectLater(
        configureDependencies(database: openTestDatabase()),
        completes,
      );
    });

    test('resolves every repository', () async {
      await configureDependencies(database: openTestDatabase());

      expect(getIt<ExerciseRepository>(), isA<DriftExerciseRepository>());
      expect(getIt<PlanRepository>(), isA<DriftPlanRepository>());
      expect(
        getIt<SessionContentRepository>(),
        isA<DriftSessionContentRepository>(),
      );
      expect(getIt<ScheduleRepository>(), isA<DriftScheduleRepository>());
      expect(getIt<SessionLogRepository>(), isA<DriftSessionLogRepository>());
      expect(getIt<SettingsRepository>(), isA<DriftSettingsRepository>());
    });

    test('hands out one instance of a repository', () async {
      await configureDependencies(database: openTestDatabase());

      expect(getIt<PlanRepository>(), same(getIt<PlanRepository>()));
    });

    test('shares one database across the repositories', () async {
      await configureDependencies(database: openTestDatabase());

      // Repositories that write in the same transaction — a plan delete
      // cascading into content and deviations — must be talking to one
      // connection, not one each.
      final database = getIt<AppDatabase>();
      await getIt<SettingsRepository>().load();
      expect(
        await database.select(database.appSettingsRows).get(),
        hasLength(1),
      );
    });
  });
}
