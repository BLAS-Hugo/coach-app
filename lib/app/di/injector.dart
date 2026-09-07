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
/// diagram: database, then repositories, then anything cross-cutting.
/// Blocs are **not** registered here — they are created at their
/// `BlocProvider`, so their lifetime is tied to the route that needs them.
Future<void> configureDependencies() async {
  await _registerDatabase();
  _registerRepositories();
  await getIt.allReady();
}

Future<void> _registerDatabase() async {
  // M1: register the Drift database as a lazy singleton, plus its DAOs.
}

void _registerRepositories() {
  // M1: register the repositories, each depending on its DAO.
}

/// Tears the graph down. Test-only: lets each test start from an empty
/// locator instead of leaking registrations across cases.
@visibleForTesting
Future<void> resetDependencies() => getIt.reset();
