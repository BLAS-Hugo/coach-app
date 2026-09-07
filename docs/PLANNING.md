# Technical Planning — Personal Sports Tracking App

**Companion to:** PRD.md
**Stack:** Flutter · Bloc · Drift · Android + iOS
**Last updated:** 2026-08-25

> **2026-08-25 — training blocks are now first-class.** A plan used to carry the dates
> and one weekly template; ending a mesocycle meant creating a second plan. The design
> handoff needs blocks as real objects (screens 4a, 4b and 5c), so `training_blocks` now
> sits between plan and weekly template, and `weekIndex` counts from the block's start
> date. A plan with a single block is exactly the old model, so nothing is lost.

---

## 1. Architecture

Feature-first, three layers, with the domain layer holding no Flutter or Drift imports.

```
UI (widgets)  →  Bloc / Cubit  →  Repository (interface)  →  Drift DAO  →  SQLite
                                       ↑
                              Domain models + pure logic
```

**Rules that matter:**

- The **occurrence engine** (§4) is pure Dart with no I/O. It is the single most important
  piece of logic in the app and must be unit-testable without a database.
- Repositories expose **domain models**, never Drift row classes. The mapping happens in
  the data layer. This is what makes the schema changeable later.
- Repositories return `Stream`s for anything the UI watches. Drift's `watch()` gives
  reactive queries for free; use them instead of manual refresh calls.
- Blocs never touch the database directly.

### Package layout

```
lib/
  app/                     app widget, routing, theme, DI wiring
  core/
    database/              Drift database, tables, DAOs, migrations
    models/                domain models (plain Dart)
    scheduling/            occurrence engine  ← pure, heavily tested
    utils/                 date helpers, unit conversion, 1RM formulas
    widgets/               shared widgets
  l10n/                    app_fr.arb + generated
  features/
    plans/                 plan list, plan editor, week overrides
    calendar/              day view, date strip, session detail
    runner/                strength runner, endurance runner, rest timer
    history/               per-exercise history, charts
    settings/
  main.dart
```

Each feature folder holds `bloc/`, `view/`, `widgets/`.

### Dependencies

| Package | Purpose | Note |
|---|---|---|
| `flutter_bloc` | State management | |
| `drift` + `drift_dev` + `sqlite3_flutter_libs` | Persistence | `drift_flutter` for the connection helper |
| `build_runner` | Codegen | Drift + freezed |
| `freezed` + `json_serializable` | Domain models, bloc states, snapshot JSON | |
| `get_it` | DI | Manual registration; skip `injectable`, the app is small |
| `go_router` | Routing | |
| `uuid` | UUID v7 primary keys | v7 sorts chronologically, useful for debugging |
| `intl` + `flutter_localizations` | Dates and l10n | |
| `fl_chart` | History charts | |
| `wakelock_plus` | Keep screen on during runner | |
| `flutter_foreground_task` | Android foreground service for the endurance timer | The risky one — see §7 |
| `audioplayers` | Interval and rest cues | Preload assets; latency matters |
| `flutter_local_notifications` | Rest timer alert when backgrounded | |

No analytics, no crash reporting, no HTTP client. If a network dependency appears in
`pubspec.lock`, something went wrong.

---

## 2. Database schema (Drift)

Every table carries `id TEXT PRIMARY KEY` (UUID v7), `createdAt`, `updatedAt`, and a
nullable `deletedAt`. This is the sync-ready baseline from PRD §8 and is non-negotiable —
retrofitting it later is the expensive path.

Define a `SyncableTable` mixin so those four columns are declared once.

### Planning side

```
exercises
  id, name, muscleGroup?, notes?

plans                                 -- a container; carries no dates
  id, name, type (strength|endurance), notes?

training_blocks                       -- one mesocycle; PRD §3
  id, planId → plans, name, orderIndex,
  startDate, durationWeeks? (int), endDate? (explicit early stop), notes?

session_templates                     -- owned by the plan, reusable across blocks
  id, planId → plans, name, notes?

weekly_slots                          -- the weekly template, one per block
  id, blockId → training_blocks, weekday (1..7),
  sessionTemplateId → session_templates
  UNIQUE(blockId, weekday) where deletedAt IS NULL

-- strength content
exercise_entries
  id, sessionTemplateId → session_templates, exerciseId → exercises,
  orderIndex, supersetGroup? (int), restSeconds?, notes?

planned_sets
  id, exerciseEntryId → exercise_entries, orderIndex,
  kind (weightReps|reps|duration),
  weight? (real), reps? (int), durationSeconds? (int), targetIntensity? (real)

-- endurance content
repeat_groups
  id, sessionTemplateId → session_templates, orderIndex, repeatCount

endurance_blocks
  id, sessionTemplateId → session_templates, repeatGroupId? → repeat_groups,
  orderIndex, role (warmup|work|recovery|cooldown),
  measure (duration|distance), targetValue (int: seconds or metres),
  intensityLabelId? → intensity_labels, notes?

intensity_labels
  id, label, orderIndex
```

**Ordering:** `orderIndex` is an integer with gaps (0, 100, 200…) so drag-reorder writes one
row instead of renumbering the list. Renormalise on save.

### Deviation side

```
week_overrides                        -- deloads, per-week swaps
  id, blockId → training_blocks,
  weekIndex (0-based from the block's startDate), weekday (1..7),
  action (replace|remove|adjustLoad),
  replacementSessionTemplateId? → session_templates,
  loadMultiplier? (real)

occurrence_moves                      -- single-occurrence reschedule
  id, blockId → training_blocks, date, targetDate
```

**There is exactly one way to express a skip**, and it is a `session_log` with status
`skipped` (PRD §5.2). This table therefore carries moves only — an earlier draft gave it
a `kind (skip|move)` column, which made a skipped occurrence representable two ways and
would have been a standing source of disagreement between the two paths.

**A block's end date is derived**, not stored, unless it was stopped early:
`endDate ?? startDate + durationWeeks × 7 − 1 day`, and null/null means ongoing.
Storing a `status` column was considered and rejected — it is a pure function of
the dates and today, and a stored copy goes stale the moment the clock passes
midnight.

### Logging side

Logs are **snapshots**. Once written they are never touched by plan edits.

```
session_logs
  id, planId → plans, blockId? → training_blocks (nullable soft ref),
  sessionTemplateId? (nullable soft ref, survives template deletion),
  date, status (inProgress|completed|skipped),
  startedAt?, completedAt?, totalDurationSeconds?, notes?,
  plannedSnapshot (TEXT, JSON)        -- full planned content when materialised

logged_exercises
  id, sessionLogId → session_logs, exerciseId → exercises,
  orderIndex, supersetGroup?, skipped (bool), notes?

logged_sets
  id, loggedExerciseId → logged_exercises, orderIndex, kind,
  plannedWeight?, plannedReps?, plannedDurationSeconds?, plannedIntensity?,
  actualWeight?,  actualReps?,  actualDurationSeconds?,  actualIntensity?,
  completed (bool)

logged_blocks
  id, sessionLogId → session_logs, orderIndex, roundIndex,
  role, measure, targetValue, intensityLabel (TEXT, denormalised),
  actualDurationSeconds?, actualDistanceMeters?, completed (bool)

app_settings                          -- single row
  id, unitWeight (kg|lb), unitDistance (km|mi), intensityScale (rpe|rir),
  defaultRestSeconds, audioCues (bool), vibration (bool), themeMode
```

`startedAt` is nullable because a **skipped** log was never started: skipping
materialises the snapshot without performing anything. A log with a null `startedAt` and
status other than `skipped` is invalid.

`plannedSnapshot` is deliberately redundant with the `logged_*` tables. The relational rows
are what history queries read; the JSON blob is the escape hatch for rendering a historical
session exactly as it was planned, including structure the relational tables flatten
(superset grouping, repeat groups). Keep it.

`intensityLabel` on `logged_blocks` is denormalised text on purpose — if the user deletes
the "Z4" label two years later, old logs must still read "Z4".

### Migrations

Drift `MigrationStrategy` with explicit stepwise migrations from schema v1. Use
`drift_dev`'s schema dumps plus `verifySelfIntegrity` in tests from day one. Do not ship a
`deleteAndRecreate` fallback — there is no cloud backup to restore from.

---

## 3. Domain models

Plain `freezed` classes mirroring the concepts in PRD §3: `Plan`, `TrainingBlock`,
`SessionTemplate`, `WeeklySlot`, `ExerciseEntry`, `PlannedSet`, `EnduranceBlock`,
`RepeatGroup`, `WeekOverride`, `OccurrenceMove`, `SessionOccurrence`, `SessionLog`,
`LoggedSet`, `LoggedBlock`, `Exercise`.

`TrainingBlock` derives what the schema does not store:

```dart
DateTime? get endDate =>            // null = ongoing
    explicitEndDate ?? (durationWeeks == null
        ? null
        : startDate.addDays(durationWeeks! * 7 - 1));

bool covers(DateTime date) =>
    !date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate!));
```

`SessionOccurrence` is the important one and does not exist in the database:

```dart
class SessionOccurrence {
  final String planId;
  final PlanType type;
  final String? sessionTemplateId;   // null for a rest day
  final DateTime date;
  final OccurrenceStatus status;     // scheduled | inProgress | completed | skipped | missed
  final String? sessionLogId;        // set once materialised
  final double? loadMultiplier;      // from a week override
}
```

---

## 4. The occurrence engine

Pure function, `core/scheduling/`. Signature roughly:

```dart
List<SessionOccurrence> computeOccurrences({
  required List<Plan> plans,
  required Map<String, List<TrainingBlock>> blocksByPlan,
  required Map<String, List<WeeklySlot>> slotsByBlock,
  required Map<String, List<WeekOverride>> overridesByBlock,
  required Map<String, List<OccurrenceMove>> movesByBlock,
  required Map<String, SessionLog> logsByKey,
  required DateRange range,
  required DateTime today,
});
```

Algorithm per plan, per block, per date in range:

1. Skip if the block does not cover the date (`startDate` .. derived `endDate`;
   a null end date is never "after").
2. `weekIndex = (date - block.startDate).inDays ~/ 7`.
3. Look up the `weekly_slot` for `date.weekday`. No slot → rest day, emit nothing.
4. Apply any `week_override` matching `(weekIndex, weekday)`: remove → emit nothing;
   replace → swap the template id; adjustLoad → carry `loadMultiplier`.
5. Apply any `occurrence_move` for that exact date: emit at `targetDate` instead.
6. Resolve status: a log exists → its status (which is how a skip surfaces); else
   date < today → `missed`; else `scheduled`.

Blocks within a plan cannot overlap (PRD §4.1), so step 1 selects at most one block
per plan per date and the loop stays O(dates × plans).

**Non-obvious correctness requirements, all of which need tests:**

- All date arithmetic runs on **date-only values at local midnight**, never on raw
  `DateTime.now()`. DST transitions make `inDays` lie if times of day are involved.
  Normalise every date at the boundary.
- Week 0 is the calendar week containing the block's `startDate`, and it may be a partial
  week. A block starting on a Thursday has a week 0 with only Thursday–Sunday. Overrides
  for "week 4" must mean the same thing to the user and the engine.
- `weekIndex` is counted from the **block's** start date, not the plan's. A plan's second
  block restarts at week 0, which is what the "semaine 3 / 5" readout on design screen 4a
  shows.
- A moved occurrence must not collide with an existing occurrence of the same plan type on
  the target date. Validate at write time, not at compute time.

This function is the app. Budget real time for its test suite (§6, M1).

---

## 5. Bloc inventory

| Bloc / Cubit | Responsibility |
|---|---|
| `CalendarBloc` | Selected date, the ±7-day window, occurrence list per date. Watches plan + log streams. |
| `SessionDetailCubit` | Loads one occurrence's planned or logged content. |
| `PlanListBloc` | Plans, filtering, soft delete, activation conflict validation. |
| `PlanEditorBloc` | The whole editor as one bloc with a draft aggregate held in state; commits to the DB in a single transaction on save. Do **not** write on every keystroke. |
| `WeekOverrideBloc` | Week view of a plan, override CRUD. |
| `StrengthRunnerBloc` | Active session state, set validation, add/remove set, superset round pointer, persistence on every mutation. |
| `EnduranceRunnerBloc` | Block pointer, round pointer, timer ticks, pause/resume/skip, foreground-service lifecycle. |
| `RestTimerCubit` | Independent countdown, shared by the strength runner. |
| `HistoryBloc` | Exercise selection, metric selection, chart series computation. |
| `SettingsCubit` | App settings, hydrated at startup. |

Use `freezed` unions for runner states — the strength runner has enough states
(`initial`, `loading`, `running`, `paused`, `finishing`, `completed`) that a sealed
hierarchy pays for itself.

**Runner persistence:** `StrengthRunnerBloc` writes to the DB on every set mutation, not
on finish. Non-negotiable for N3 (surviving process death). Same for the endurance runner
on every block advance.

---

## 6. Milestones

Ordered so a genuinely usable strength app exists at the end of M4. The two expensive
features — guided timer and supersets — land after that, which means slipping them delays
nothing else.

Estimates assume solo part-time work and are ranges, not commitments.

### M0 — Foundations · ~2–3 days

Project scaffold, folder structure, `get_it` wiring, `go_router` routes, theme (light/dark),
`flutter_localizations` + `app_fr.arb` with the lint that catches hardcoded strings, Drift
database with the `SyncableTable` mixin and schema v1, DAO scaffolding, `melos`-free
single-package setup, analysis options with strict lints.

**Done when:** app builds on both platforms, DB opens, one string renders from the ARB.

### M1 — Domain, persistence, occurrence engine · ~3–4 days

All tables from §2, all domain models, all repositories with stream-based reads, and the
occurrence engine with its test suite. No UI.

**Done when:** unit tests cover partial first weeks, DST boundaries, null end dates,
derived vs explicit block end dates, consecutive blocks in one plan, overrides, moves,
skips, and two concurrent plans of different types.

### M2 — Plan editor, strength · ~4–5 days

Plan list, create/edit plan metadata, session template builder, inline exercise
autocomplete with create-on-the-fly, planned sets with all four measurement kinds,
drag reorder, weekday assignment, overlap validation on save.

**Done when:** a full strength program can be entered and re-opened intact.

### M3 — Day view and session detail · ~3 days

Home screen, ±7-day date strip with per-day markers, occurrence cards, session detail for
both types, skip and move actions, empty states.

**Done when:** a plan created in M2 renders correctly across the two-week window.

### M4 — Strength runner, logging, rest timer, settings · ~5–6 days

Start session → snapshot → set-by-set logging with one-tap validation, inline edits,
add/remove set, skip exercise, rest timer with background notification and audio cue,
pause/resume across process death, finish and write the completed log.

Also the **settings screen** (PRD §5.7): units, intensity scale, default rest duration,
audio and vibration toggles, theme. `SettingsCubit` is hydrated at startup from M0; this
milestone gives it a UI, because rest duration and unit display first become
user-visible here.

**Done when:** a full training week can be logged and re-read. **The app is now
independently useful — everything after this is additive.**

### M5 — Endurance plans and basic runner · ~3–4 days

Endurance session template builder (blocks, roles, measures, intensity labels, repeat
groups), endurance session detail, intensity-label management in settings, and a manual
runner: block list, stopwatch, manual advance, actuals recorded. No background service yet.

**Done when:** an interval session can be built and completed with the app in the
foreground.

### M6 — Guided timer · ~4–6 days · highest risk

Auto-advancing countdown, `flutter_foreground_task` service on Android, iOS background
audio session, wakelock, audio cues and vibration at block boundaries, round counter,
skip forward/back. Real-device testing on both platforms with the screen locked.

**Done when:** a 6 × 400 m session runs correctly with the phone in a pocket, screen off,
on both platforms.

### M7 — Supersets · ~3–4 days

Superset grouping in the editor (select entries → group, ungroup, visual bracket), and the
interleaved round-based presentation in the strength runner with correct rest-timer
behaviour.

**Done when:** an A1/B1 superset of 4 rounds logs in the right order with rest only after
B1 each round.

### M8 — Week overrides · ~2–3 days

Block week view, per-week swap/remove, load multiplier for deloads, correct propagation
through the occurrence engine (engine support already exists from M1; this is UI).

**Done when:** week 4 of a plan can be turned into a −20 % deload and the day view reflects
it.

### M9 — History and charts · ~3–4 days

Per-exercise log list, metric selection (top set, estimated 1RM via Epley, session volume),
`fl_chart` line charts, endurance totals over time, plan completion rate, calendar heat
view.

**Done when:** three months of seeded data render without jank.

### M10 — Hardening and release · ~3–4 days

Migration tests with `verifySelfIntegrity`, integration test of the full daily flow, unit
conversion correctness, empty and error states, app icons and splash, release signing for
both platforms, TestFlight/internal track setup.

**Total: roughly 33–47 working days part-time.** Usable strength app at ~17–21.

### Coverage check

Every V1 requirement in the PRD maps to a milestone: plans and editor → M2, day view and
±7-day strip → M3, strength logging and rest timer and settings → M4, endurance plans → M5,
guided timer → M6, supersets → M7, week overrides → M8, history and charts → M9, l10n
infrastructure → M0, sync-ready schema → M1, migrations and release → M10. Nothing marked
deferred in PRD §7 appears in any milestone.

---

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Background timer on iOS** | M6 blocked | iOS gives no general background execution. The workable path is an active audio session — the app plays silent audio to stay alive and fires cues over it. Prototype this in a throwaway project **during M5**, before committing M6's scope. If it proves unreliable, degrade to local notifications scheduled at known block boundaries. |
| **Android background restrictions** | M6 blocked | `flutter_foreground_task` with a persistent notification, plus battery-optimisation exemption prompting. Test on a Xiaomi or Samsung device, not just a Pixel or an emulator — aggressive OEM killers are where this breaks. |
| **Occurrence engine date bugs** | Wrong sessions shown; corrupted history | Date-only normalisation at every boundary, plus the M1 test suite. Do not skip this to move faster; every downstream feature reads from this function. |
| **Plan editor complexity** | M2 overruns | Draft-aggregate-in-bloc with one transactional save keeps the DB out of the interaction loop. Resist adding per-field autosave. |
| **No backup in V1** | Total data loss on device loss or a bad migration | Accepted by decision. Partially mitigated by the sync-ready schema and by refusing a `deleteAndRecreate` migration fallback. If V1 slips past a couple of months of real use, reconsider — a share-sheet dump of the `.sqlite` file is roughly two hours of work. |
| **Scope creep into nutrition/recovery** | Product dilution | Listed as a permanent anti-goal in the PRD. |
| **Supersets touching two subsystems** | M7 overruns | Model supersets as groups-of-one by default (PRD §4.4) so the runner already has round-based logic before M7; M7 then only adds grouping UI and multi-entry rounds. |

---

## 8. Testing strategy

| Layer | Approach |
|---|---|
| Occurrence engine | Exhaustive unit tests. Table-driven. This is where testing effort concentrates. |
| Unit conversion, 1RM, volume | Unit tests with known values. |
| Repositories | Drift in-memory database, real SQL, no mocks. |
| Blocs | `bloc_test`, with fake repositories. |
| Migrations | `drift_dev` schema dumps, `verifySelfIntegrity`, one test per version step. |
| Flows | `integration_test`: create plan → see it on the day view → run it → see it in history. |
| Timer | Manual on real devices, both platforms, screen locked. Not automatable; budget for it. |

---

## 9. Conventions

- French is the only UI language; **every** user-visible string goes through the ARB, no
  exceptions, so V2's English is additive.
- Code, comments, commit messages, and both of these documents are in English.
- Dates stored as UTC-midnight epoch days or ISO date strings; never as local `DateTime`
  with a time component.
- Weights stored in kilograms and distances in metres. Unit preference is a display
  concern applied at the presentation layer only.
- Conventional commits, one branch per milestone.