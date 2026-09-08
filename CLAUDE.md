# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

**Coach App** is a personal offline strength/endurance training tracker, built on a
[Very Good CLI](https://github.com/VeryGoodOpenSource/very_good_cli) scaffold. `docs/PRD.md` (product
spec) and `docs/PLANNING.md` (technical plan: architecture, schema, bloc inventory, occurrence engine
algorithm, milestones) are the source of truth for what to build and how. **Read both before starting
any feature work**, and check `docs/PLANNING.md` §6 to see which milestone is current.

**M0 and M1 are done; M2 (plan editor, strength) is next.** In place: theme, `go_router` shell and
`get_it` wiring; `core/utils/` date types; the `core/scheduling/` occurrence engine; Drift schema v1;
and `core/repositories/`, which exposes domain models over `watch()` streams and holds the write-time
validation the schema cannot express. M2 is the first milestone with real blocs and screens — the
`features/` folders are still placeholder pages behind the three tabs.

`pubspec.yaml` carries `bloc`/`flutter_bloc`, `drift`/`drift_flutter`, `freezed`, `get_it`, `go_router`,
`intl`, `json_annotation`, `meta` and `uuid`. The rest of the planned set in `docs/PLANNING.md` §1
(`fl_chart`, `flutter_foreground_task`, `wakelock_plus`, `audioplayers`,
`flutter_local_notifications`) is deliberately absent — add each when its milestone arrives, not
preemptively.

## Commands

This project has three flavors: `development`, `staging`, `production`, each with its own
`lib/main_<flavor>.dart` entrypoint.

```sh
# Run
flutter run --flavor development --target lib/main_development.dart

# Install deps
flutter pub get

# Analyze (very_good_analysis + bloc_lint rules, see analysis_options.yaml)
flutter analyze

# Bloc-specific lints (bloc_lint package, stricter than the analyzer rules)
dart run bloc_tools:bloc lint .

# All tests with coverage (Very Good CLI test runner). `very_good.yaml` holds
# the exclusion list and the 100% floor, so this fails locally exactly where
# CI would — no flags needed, and no need to trust the raw lcov, which counts
# generated code and reads about 35%.
very_good test --coverage --test-randomize-ordering-seed random

# Single test file
flutter test test/core/scheduling/occurrence_engine_test.dart

# What the last run actually came to, and which files hold the gaps. The CLI
# only prints a percentage when coverage is short; this prints it either way.
tool/coverage.sh

# Coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/

# Code generation (drift, freezed, json_serializable). Run after touching a table, a domain model,
# a DAO, or any freezed bloc state — the .g.dart / .freezed.dart files are gitignored, so a fresh
# clone does not analyze until this has run.
dart run build_runner build

# Regenerate localizations after editing an .arb file
flutter gen-l10n --arb-dir="lib/l10n/arb"
```

CI (`.github/workflows/main.yaml`) runs the Very Good `flutter_package` workflow with
`run_bloc_lint: true`, a semantic-PR check, and a markdown spell check — match that locally before
pushing.

## Architecture (target — see `docs/PLANNING.md` for full detail)

Feature-first, three layers, unidirectional:

```
UI (widgets) → Bloc / Cubit → Repository (interface) → Drift DAO → SQLite
                                    ↑
                           Domain models + pure logic
```

- **The occurrence engine** (`core/scheduling/`) is pure Dart with no I/O — it derives which
  training sessions fall on which dates from a plan's weekly template, week overrides, and per-occurrence
  exceptions. It is the single most important piece of logic in the app (`docs/PLANNING.md` §4) and must
  stay unit-testable without a database. All date arithmetic in it must use date-only values at local
  midnight, never raw `DateTime.now()`.
- Repositories expose **domain models only, never Drift row classes** — mapping happens in the data
  layer so the schema stays changeable.
- Repositories return `Stream`s (via Drift's `watch()`) for anything the UI observes; blocs never touch
  the database directly.
- Session logs are **snapshots**: starting a session materializes the planned content into a
  `session_log`; later edits to the plan never alter an already-materialized log.
- Every table carries a UUID (v7) primary key, `createdAt`, `updatedAt`, and a nullable `deletedAt`
  (soft delete) — this is a sync-ready baseline for a future backup feature and is non-negotiable
  (`docs/PRD.md` §8). Never use autoincrement integer keys or hard deletes.
- Package layout under `lib/`: `app/` (DI, routing, theme), `core/database` (schema in `tables/`,
  queries in `dao/`, row↔domain mapping in `mappers.dart`), `core/models`, `core/repositories`,
  `core/scheduling`, `core/utils`, `core/widgets`, `l10n/`, and one folder per feature under
  `features/` (`plans`, `calendar`, `runner`, `history`, `settings`), each with `data/`, `domain/`
  and `presentation/` — the last holding `bloc/`, `view/` and `widgets/`.

## Conventions

- **French is the only UI language in V1.** Every user-visible string goes through
  `lib/l10n/arb/app_fr.arb`, the only ARB file, and is accessed via `context.l10n`; never hardcode a
  string in a widget. Code, comments, commit messages, and docs are in English.
- Dates are stored as UTC-midnight epoch days or ISO date strings, never local `DateTime` with a time
  component. Weights are stored in kilograms, distances in metres; unit preference (kg/lb, km/mi) is a
  display-layer concern only.
- No network calls, analytics, or crash reporting — ever, by design (`docs/PRD.md` non-goals). If a
  network-related package shows up in `pubspec.lock`, something is wrong.
- Conventional commits; one branch per milestone.
