import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/content_dao.dart';
import 'package:coach_app/core/database/dao/exercise_dao.dart';
import 'package:coach_app/core/database/dao/logging_dao.dart';
import 'package:coach_app/core/database/dao/planning_dao.dart';
import 'package:coach_app/core/database/dao/scheduling_dao.dart';
import 'package:coach_app/core/database/dao/settings_dao.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

/// The single service locator instance.
///
/// Registration is manual and lives in [configureDependencies]; the app is
/// small enough that `injectable` and its codegen would not pay for itself
/// (see `docs/PLANNING.md` §1).
final GetIt getIt = GetIt.instance;

/// Wires the object graph. Called from `bootstrap` before `runApp`, so
/// anything registered here is available for the first frame.
///
/// Registration order is layered, matching the arrows in the architecture
/// diagram: database, then DAOs, then repositories. Blocs are **not**
/// registered here — they are created at their `BlocProvider`, so their
/// lifetime is tied to the route that needs them.
///
/// Everything is a lazy singleton, so nothing opens the database until
/// something actually reads from it, and every repository shares one
/// connection — which is what lets a delete cascade across three DAOs run
/// in a single transaction.
///
/// [database] is for tests, which pass an in-memory one rather than
/// touching the device's file system.
Future<void> configureDependencies({AppDatabase? database}) async {
  _registerDatabase(database);
  _registerRepositories();
  await getIt.allReady();
}

void _registerDatabase(AppDatabase? database) {
  getIt
    ..registerLazySingleton<AppDatabase>(
      () => database ?? AppDatabase(),
      dispose: (instance) => instance.close(),
    )
    ..registerLazySingleton<ExerciseDao>(() => ExerciseDao(getIt()))
    ..registerLazySingleton<PlanningDao>(() => PlanningDao(getIt()))
    ..registerLazySingleton<ContentDao>(() => ContentDao(getIt()))
    ..registerLazySingleton<SchedulingDao>(() => SchedulingDao(getIt()))
    ..registerLazySingleton<LoggingDao>(() => LoggingDao(getIt()))
    ..registerLazySingleton<SettingsDao>(() => SettingsDao(getIt()));
}

void _registerRepositories() {
  getIt
    ..registerLazySingleton<ExerciseRepository>(
      () => DriftExerciseRepository(getIt()),
    )
    ..registerLazySingleton<PlanRepository>(
      () => DriftPlanRepository(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<SessionContentRepository>(
      () => DriftSessionContentRepository(getIt()),
    )
    ..registerLazySingleton<ScheduleRepository>(
      () => DriftScheduleRepository(getIt()),
    )
    ..registerLazySingleton<SessionLogRepository>(
      () => DriftSessionLogRepository(getIt()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => DriftSettingsRepository(getIt()),
    );
}

/// Tears the graph down, closing the database with it. Test-only: lets each
/// test start from an empty locator instead of leaking registrations across
/// cases.
@visibleForTesting
Future<void> resetDependencies() => getIt.reset();
