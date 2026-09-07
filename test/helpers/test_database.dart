import 'package:coach_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A throwaway database on an in-memory SQLite.
///
/// Repository tests run against real SQL rather than a mocked DAO
/// (`docs/PLANNING.md` §8): the constraints, the partial unique index and
/// the `deletedAt IS NULL` filtering are exactly the parts worth testing,
/// and none of them exist in a fake.
AppDatabase openTestDatabase() {
  // Each test opens its own database, which is exactly the shape drift's
  // "multiple instances" warning is meant to catch in an app. Here it is
  // the point, and the warning would bury the test output.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// A clock stuck at [instant], so a test can assert what a write stamped.
DateTime Function() clockAt(DateTime instant) =>
    () => instant;

/// A clock that returns each of [instants] once, then repeats the last one.
///
/// Lets a test write, advance, and write again without reaching for a real
/// wall clock it cannot predict.
DateTime Function() clockOver(List<DateTime> instants) {
  var index = 0;
  return () {
    final instant = instants[index];
    if (index < instants.length - 1) index++;
    return instant;
  };
}
