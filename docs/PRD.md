# PRD — Personal Sports Tracking App

**Working title:** Coach App
**Owner:** Hugo
**Platform:** Flutter — Android + iOS
**Status:** V1 scope locked
**Last updated:** 2026-08-25
---

## 1. Summary

A personal training app for planning and executing structured strength and endurance
programs. The user builds a program once, the app tells them what to train today, and
they log what they actually did. Everything works offline against a local database.

The app is explicitly **training only**. Nutrition, sleep, recovery scores, body weight
tracking, and wellness metrics are out of scope permanently, not just for V1.

### Audience

The user themselves and a small number of close friends. This is not a consumer product:
there is no onboarding funnel, no accounts, no social layer, no monetisation. Design
decisions should favour a dense, fast, opinionated interface over a friendly generic one.

### V1 in one sentence

Create and edit strength and endurance programs, see the sessions scheduled for today and
the surrounding two weeks, run a session with a guided timer and per-set logging, and look
back at per-exercise progress.

---

## 2. Goals and non-goals

### Goals

| # | Goal |
|---|------|
| G1 | The user can define a strength program and an endurance program without leaving the app or using a spreadsheet. |
| G2 | Opening the app answers "what am I training today?" in under one second, with no navigation. |
| G3 | Logging a set during a session takes at most two taps for the common case (planned values were achieved). |
| G4 | A program can be edited mid-block without corrupting or rewriting already-completed sessions. |
| G5 | The user can see whether they are progressing on a given exercise over weeks and months. |
| G6 | The app is fully functional with the device in airplane mode, permanently. |

### Non-goals for V1

- Nutrition, sleep, recovery, HRV, body measurements, weight tracking, photos.
- Accounts, login, cloud sync, multi-device.
- Social features, sharing, leaderboards, coach/athlete relationships.
- Wearable, HR strap, GPS, or health-platform integration (Health Connect / HealthKit).
- Program templates library, AI program generation, exercise video demos.
- English localisation (French only in V1 — see §7.9).
- Backup and export (see §9, V2).

### Explicit anti-goals (never)

- Any nutrition or recovery feature.
- Advertising, analytics SDKs, telemetry, crash reporting that phones home.

---

## 3. Core concepts and vocabulary

These terms are used consistently throughout this document and should map 1:1 to code
identifiers.

**Plan** — a named training program with a type (`strength` or `endurance`), holding an
ordered sequence of *training blocks*. A plan carries no dates of its own; its blocks do.
Example: "Upper/Lower 4x".

**Training block** — one mesocycle within a plan: a name, a start date, a duration in
weeks, and exactly one *weekly template* that repeats for that duration. Example: "Bloc 2
— intensification, 5 semaines". A block may be stopped early, which fixes its end date at
the last day of the current week. Blocks within a plan do not overlap.

Note the deliberate collision of vocabulary: a *training block* is a multi-week segment of
a plan, whereas an *endurance block* (below) is a segment of a single endurance session.
The French UI calls both "bloc"; context separates them. Code never does — the identifiers
are `TrainingBlock` and `EnduranceBlock`.

**Weekly template** — for each weekday, zero or one *session template*. This is the
repeating pattern of a training block, not of the plan as a whole.

**Session template** — a named workout belonging to a plan. For strength: an ordered list
of exercise entries with planned sets. For endurance: an ordered list of interval blocks.

**Week override** — a per-week deviation from the weekly template within a training block.
Used for deloads and progression. An override can replace a weekday's session template,
remove it, or adjust loads.

**Session occurrence** — a concrete instance of a session template on a concrete date,
derived from the training block's start date, its weekly template, and any override for
that week. Occurrences are computed, not stored, until they are started (§5.3).

**Session log** — the persisted record created when the user starts an occurrence. Holds a
frozen snapshot of what was planned plus everything actually performed.

**Exercise** — a named movement with a stable identity, so history can be aggregated across
plans. Example: "Développé couché".

**Set** — one work set within a strength exercise entry. Has planned values and actual
values.

**Endurance block** — one segment of an endurance session. Warmup, work interval,
recovery, or cooldown. Unrelated to a *training block*.

---

## 4. Data model requirements (functional view)

The technical schema lives in the planning document. This section states what the model
must be capable of expressing.

### 4.1 Plans

- A plan has: name, type (`strength` | `endurance`), notes. It has no dates.
- A plan holds an ordered list of **training blocks**. A block has: name, start date,
  duration in weeks, an optional explicit end date, notes.
- **A block's end date is derived** from its start date and duration unless an explicit end
  date is set, which is what "stop this block after this week" does. A block with neither a
  duration nor an end date is ongoing and generates sessions indefinitely.
- **Blocks within one plan may not overlap.** Attempting to create or move a block so that
  its date range overlaps a sibling is blocked.
- **At most one active plan per type at a time**, where a plan is active if any of its
  blocks covers today. A strength plan and an endurance plan may run concurrently, which is
  why a day can show two sessions.
- Attempting to activate a plan whose blocks overlap those of another plan of the same type
  is **blocked**, with a message prompting the user to stop the existing block first.
- Plans and blocks are **soft-deleted**. Deleting either hides it from the plan list but
  preserves all session logs attached to it, and those logs remain visible in history.
- **A block that has started cannot be deleted**, only stopped — a hard delete would
  destroy history. See §6.4.

### 4.2 Strength session templates

A strength session template contains an ordered list of **exercise entries**. Each entry
has:

- a reference to an exercise,
- an optional group tag for supersets (§4.4),
- optional per-exercise rest duration (defaults to a global setting),
- notes,
- an ordered list of **planned sets**.

A planned set has a **measurement kind** which determines which fields are meaningful:

| Kind | Fields | Example |
|------|--------|---------|
| `weightReps` | weight, reps | 80 kg × 5 |
| `reps` | reps | 12 pull-ups |
| `duration` | seconds | 45 s plank |
| `weightDuration` | weight, seconds | 20 kg × 40 s farmer's walk |

Every planned set may additionally carry an optional **target RPE or RIR** value. The user
chooses RPE or RIR globally in settings; only one scale is shown.

### 4.3 Endurance session templates

An endurance session template contains an ordered list of **blocks**. Each block has:

- a **role**: `warmup`, `work`, `recovery`, `cooldown`,
- a **measure**: either `duration` (seconds) or `distance` (metres),
- a target value for that measure,
- an optional **intensity label** — a free-choice value from a small user-editable list
  (e.g. "Z2", "Z4", "seuil", "RPE 7", "4:30/km"). This is a label only; the app does not
  compute or measure intensity, and there are no sensors involved.
- optional notes.

Blocks can be grouped into a **repeat group**: an ordered subset of blocks with a repeat
count, so "6 × (400 m fast / 90 s easy)" is one group of two blocks with count 6, not
twelve blocks.

### 4.4 Supersets

Exercise entries within a strength session may be tagged into a **superset group**.
Entries sharing a group tag are performed alternating, set by set. During execution the
runner presents them interleaved: A1 set 1 → B1 set 1 → A1 set 2 → B1 set 2, etc. Rest
timer only fires after the last exercise in the group for a given round.

A group of one is just a normal exercise. This keeps the model uniform.

### 4.5 Exercises

A minimal table: id, name, optional muscle group, optional notes, plus soft-delete and
timestamps. **No seeded catalogue and no dedicated browse screen in V1.**

Exercises are created inline while building a session: the user types a name, an
autocomplete offers existing matches, and choosing "create" makes a new one. This exists
solely so that per-exercise history aggregates correctly rather than fragmenting across
spelling variants.

---

## 5. Features

### 5.1 Home — the day view

The landing screen. It answers "what do I train today".

- Shows **today's session occurrences** (0, 1, or 2 — at most one per active plan type) as
  cards. A card shows the session name, its plan, its type, a one-line summary (e.g.
  "5 exercices · ~45 min" or "6 × 400 m"), and its state.
- Above the cards, a **horizontal date strip covering the previous 7 days and the next 7
  days**, centred on today. Each date shows dots or markers indicating: session scheduled,
  session completed, session missed, rest day.
- Tapping a date in the strip switches the card area to that date. Today is one tap away at
  all times.
- Tapping a card opens the session detail (§5.2).
- If no plan is active, the screen shows an empty state that leads directly to plan
  creation.

**Session states:** `scheduled` (future or today, not started), `inProgress`,
`completed`, `skipped`, `missed` (a past scheduled date with no log).

**Missed sessions do not cascade.** The app never auto-shifts a plan because a session was
missed. A missed session stays visible in the past as missed. The user may explicitly mark
it skipped to clear it, or move a single occurrence to another date.

### 5.2 Session detail

Read-only-ish view of what a session contains, reachable from any date in the strip.

- **Strength:** ordered exercise list; each row shows the exercise name and its planned sets
  in compact notation (`4 × 8 @ 60 kg`, `3 × 12`, `3 × 45 s`). Superset groups are visually
  bracketed. Per-exercise notes visible.
- **Endurance:** ordered block list with repeat groups rendered as groups
  (`6 × [400 m Z5 / 90 s Z1]`), plus total planned duration or distance where computable.
- Primary action: **Start session** (today or past dates). Future dates show the plan but
  no start action.
- Secondary actions: mark skipped, move this occurrence to another date, jump to the plan
  editor.
- If a log already exists for this date, the view shows the logged actuals instead of the
  plan, with planned values shown alongside for comparison.

### 5.3 Running a session

Starting an occurrence **materialises a session log**: the planned content is snapshotted
into the log, and from that moment the log is independent of the plan. Later edits to the
plan never alter this log. This is the mechanism that satisfies G4.

#### Strength runner

- One exercise (or superset group) in focus at a time, with the full list accessible.
- Each set row is pre-filled with its planned values. The common path — "I did exactly what
  was planned" — is a single tap on a validate control. Editing weight, reps, duration, or
  RPE/RIR is done inline on the row.
- The user can **add a set**, **remove a set**, and **skip an exercise** during the session.
  These changes affect the log only, never the plan.
- Completing a set starts the **rest timer** (§5.5) unless the exercise is mid-superset
  round.
- A session can be paused and resumed later, including after the app is killed; state is
  persisted continuously.
- Finishing produces a completed log with a duration and optional session notes.

#### Endurance runner — guided timer

- Presents the block sequence as a timeline with the current block highlighted.
- For `duration` blocks, a countdown runs automatically and advances to the next block at
  zero, with an audio cue and a vibration.
- For `distance` blocks, the app **cannot** measure distance (no GPS in V1). The block shows
  its target and an elapsed stopwatch; the user advances manually with a large tap target,
  and the elapsed time is recorded as the actual.
- Repeat groups display current round out of total ("Série 3 / 6").
- Manual controls at all times: pause, resume, skip forward, go back a block.
- The timer must keep running with the screen off and the app backgrounded, and audio cues
  must still fire. The screen stays awake while the runner is in the foreground.
- On finish, the log records actual duration per block and total session duration.

### 5.4 Plan creation and editing

A plan editor reachable from a plans list.

**Creating a plan:**

1. Choose type — strength or endurance. Type is fixed after creation.
2. Name the plan.
3. Create its first training block: name, start date, duration in weeks.
4. Build session templates. Templates belong to the plan, so a later block can reuse them.
5. Assign session templates to weekdays in that block's weekly template.

**Building a strength session template:** add exercises via the inline autocomplete
(§4.5), reorder by drag, add planned sets per exercise, set the measurement kind per
exercise, optionally group exercises into a superset, optionally set rest duration and
notes.

**Building an endurance session template:** add blocks with role, measure, target value,
and intensity label; reorder by drag; wrap a contiguous selection into a repeat group with
a count.

**Editing an existing plan** is the same editor. Editing rules:

- Changes apply to **future occurrences only**, from today forward.
- Occurrences already started or completed are untouched (they are snapshots).
- Past occurrences that were never started are also untouched — they remain rendered from
  the plan as it was, using the plan's own version history where necessary, or are simply
  shown as missed without detail. (Simplest acceptable behaviour: past unstarted
  occurrences render from the current template; this is a known, accepted imprecision.)
- Shortening a training block, or stopping it early, makes occurrences after its new end
  date disappear from the calendar. Existing logs remain.

**Week overrides:** from a block's week view, the user can pick a specific week of that
block and, for that week only, swap a weekday's session, remove a session, or apply a load
adjustment (e.g. "−20 % on all working weights") for a deload.

### 5.5 Rest timer

- Countdown between sets, default duration from settings, overridable per exercise entry in
  the plan and adjustable live during the session.
- Runs in the background, fires an audio cue and vibration at zero.
- Skippable and extendable (+30 s) with one tap.

### 5.6 History and progress

- **Per-exercise view:** every logged set for a given exercise across all plans, newest
  first, plus a chart of a chosen metric over time. Metrics: top set weight, estimated 1RM
  (Epley), total volume (Σ weight × reps) per session.
- **Endurance view:** per-session totals over time — total duration, total distance where
  entered, and volume at each intensity label.
- **Plan-level view:** completion rate (sessions completed vs scheduled) for the current
  plan, and a simple calendar heat view.
- Charts are read-only; no goal setting, no PRs celebration, no streaks in V1.

### 5.7 Settings

- Units: kg / lb, km / mi. Default kg and km.
- Intensity scale: RPE or RIR.
- Default rest duration.
- Audio cue and vibration toggles.
- Intensity label list management (add/remove labels used in endurance blocks).
- Theme: system / light / dark.

### 5.8 Non-functional requirements

| # | Requirement |
|---|-------------|
| N1 | Cold start to a rendered day view under 1 s on mid-range hardware. |
| N2 | The app never makes a network request in V1. No analytics, no crash reporting. |
| N3 | The session runner survives process death; a session in progress is fully recoverable. |
| N4 | The endurance timer stays accurate to within 1 s per block with the screen off. |
| N5 | All database schema changes ship with a tested Drift migration. |
| N6 | Every table carries a UUID primary key, `createdAt`, `updatedAt`, and a soft-delete flag (§8). |

### 5.9 Localisation

**V1 ships French-only.** However, the app is built on `flutter_localizations` with a
single `app_fr.arb` from the first commit. No user-visible string is hardcoded in a widget.
Adding English in V2 is then a matter of adding `app_en.arb` and a language setting, with
no screen rewrites.

---

## 6. User flows

### 6.1 First run

App opens → empty day view → "Créer un plan" → type selection → plan metadata → session
template builder → weekday assignment → save → day view now shows today's session if one
falls today.

### 6.2 Daily use

App opens → today's card(s) → tap card → session detail → "Commencer" → runner → log sets or
blocks → finish → return to day view with the card marked completed.

### 6.3 Deload week

Plans list → open plan → week view → select week 4 → "Modifier cette semaine" → apply −20 %
load adjustment or swap sessions → save → week 4's occurrences reflect the override; all
other weeks unchanged.

### 6.4 Ending a training block and starting the next

Plans list → open current plan → "Arrêter le bloc après cette semaine" → the block's end
date is fixed at the last day of the current week → add a new block starting the day after,
seeded by duplicating the finished block's weekly template → adjust → no overlap conflict →
the new block's sessions appear from that date.

Completed session logs inside the finished block are untouched by any of this: they hold
their own snapshot of what was planned on the day they ran.

---

## 7. Out of scope for V1, with rationale

| Item | Why deferred |
|------|--------------|
| Backup / export | Explicitly deferred by the user. Noted risk: months of training data with no recovery path. Mitigated partly by the sync-ready schema (§8). |
| Cloud backup | V2. See §8 and §9. |
| English localisation | V2. Infrastructure is in place from V1. |
| GPS / distance measurement | Requires location permissions and background tracking; distance blocks are user-advanced in V1. |
| Exercise browse screen and seeded catalogue | The inline autocomplete covers the actual need. |
| Program sharing | Would be a plan-as-JSON export through the share sheet, not a backend. V2 at the earliest. |
| Health Connect / HealthKit | Explicit non-goal; adds permissions and review surface for no personal benefit. |
| Plan templates and duplication | Nice-to-have; "duplicate plan" is a strong V1.1 candidate if plan creation proves tedious. |

---

## 8. Cloud posture

**V1 is offline-only. No backend, no network code, no accounts.**

The V2 direction is a **cloud snapshot backup for a single device**, not multi-device sync:
an encrypted dump of the local database is uploaded on a schedule and on demand, and can be
restored onto a fresh install. One device is authoritative. There is no merge logic, no
conflict resolution, and no expectation of using the app on two phones simultaneously.

To keep that option cheap, **V1's schema is built sync-ready from the first migration**:

- UUID (v4 or v7) primary keys on every table, never autoincrement integers.
- `createdAt` and `updatedAt` timestamps on every row.
- Soft deletes (`deletedAt` nullable) rather than hard deletes, so a deletion is a
  syncable fact.
- No logic that depends on rowid ordering or integer key sequence.

This costs almost nothing now and is the expensive part to retrofit later.

---

## 9. Roadmap beyond V1

**V1.1 — quality of life**
Duplicate a plan. Duplicate a session template. Reorder plans. Quick "repeat last session"
for unplanned training.

**V2 — durability and reach**
Cloud snapshot backup (single-device, last-write-wins, encrypted). Manual JSON export and
import through the share sheet. English localisation via `app_en.arb`.

**V3 and beyond — candidates, unranked**
Additional program types beyond strength and endurance (mobility, skill work) — the plan
type is an enum designed to be extended. Program sharing with friends as a JSON file.
Estimated-1RM-driven auto-progression. Plan templates.

---

## 10. Success criteria

V1 is done when the user has run a full training block — start to end date, including at
least one deload week — entirely inside the app, without falling back to a spreadsheet or
notes app at any point, and without losing data.