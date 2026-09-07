import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/models/models.dart';

/// Row-to-domain and domain-to-row mapping.
///
/// This file is the whole reason the repositories can promise to expose
/// domain models and never Drift row classes (`docs/PLANNING.md` §1): the
/// schema is free to change as long as the mapping absorbs it.
///
/// The `toRow` side takes the timestamp rather than reading a clock, so the
/// rows written by one transaction all carry the same instant.
extension ExerciseRowMapper on ExerciseRow {
  Exercise toDomain() => Exercise(
    id: id,
    name: name,
    muscleGroup: muscleGroup,
    notes: notes,
  );
}

extension ExerciseMapper on Exercise {
  ExerciseRow toRow(DateTime at) => ExerciseRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    name: name,
    muscleGroup: muscleGroup,
    notes: notes,
  );
}

extension PlanRowMapper on PlanRow {
  Plan toDomain() => Plan(id: id, name: name, type: type, notes: notes);
}

extension PlanMapper on Plan {
  PlanRow toRow(DateTime at) => PlanRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    name: name,
    type: type,
    notes: notes,
  );
}

extension TrainingBlockRowMapper on TrainingBlockRow {
  /// The row's `endDate` is the domain model's *explicit* end date: the one
  /// the user set by stopping the block early. The other end date — the one
  /// the duration implies — is derived on the model and never stored.
  TrainingBlock toDomain() => TrainingBlock(
    id: id,
    planId: planId,
    name: name,
    orderIndex: orderIndex,
    startDate: startDate,
    durationWeeks: durationWeeks,
    explicitEndDate: endDate,
    notes: notes,
  );
}

extension TrainingBlockMapper on TrainingBlock {
  TrainingBlockRow toRow(DateTime at) => TrainingBlockRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    planId: planId,
    name: name,
    orderIndex: orderIndex,
    startDate: startDate,
    durationWeeks: durationWeeks,
    endDate: explicitEndDate,
    notes: notes,
  );
}

extension SessionTemplateRowMapper on SessionTemplateRow {
  SessionTemplate toDomain() =>
      SessionTemplate(id: id, planId: planId, name: name, notes: notes);
}

extension SessionTemplateMapper on SessionTemplate {
  SessionTemplateRow toRow(DateTime at) => SessionTemplateRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    planId: planId,
    name: name,
    notes: notes,
  );
}

extension WeeklySlotRowMapper on WeeklySlotRow {
  WeeklySlot toDomain() => WeeklySlot(
    id: id,
    blockId: blockId,
    weekday: weekday,
    sessionTemplateId: sessionTemplateId,
  );
}

extension WeeklySlotMapper on WeeklySlot {
  WeeklySlotRow toRow(DateTime at) => WeeklySlotRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    blockId: blockId,
    weekday: weekday,
    sessionTemplateId: sessionTemplateId,
  );
}

extension ExerciseEntryRowMapper on ExerciseEntryRow {
  ExerciseEntry toDomain() => ExerciseEntry(
    id: id,
    sessionTemplateId: sessionTemplateId,
    exerciseId: exerciseId,
    orderIndex: orderIndex,
    supersetGroup: supersetGroup,
    restSeconds: restSeconds,
    notes: notes,
  );
}

extension ExerciseEntryMapper on ExerciseEntry {
  ExerciseEntryRow toRow(DateTime at) => ExerciseEntryRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    sessionTemplateId: sessionTemplateId,
    exerciseId: exerciseId,
    orderIndex: orderIndex,
    supersetGroup: supersetGroup,
    restSeconds: restSeconds,
    notes: notes,
  );
}

extension PlannedSetRowMapper on PlannedSetRow {
  PlannedSet toDomain() => PlannedSet(
    id: id,
    exerciseEntryId: exerciseEntryId,
    orderIndex: orderIndex,
    kind: kind,
    weight: weight,
    reps: reps,
    durationSeconds: durationSeconds,
    targetIntensity: targetIntensity,
  );
}

extension PlannedSetMapper on PlannedSet {
  PlannedSetRow toRow(DateTime at) => PlannedSetRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    exerciseEntryId: exerciseEntryId,
    orderIndex: orderIndex,
    kind: kind,
    weight: weight,
    reps: reps,
    durationSeconds: durationSeconds,
    targetIntensity: targetIntensity,
  );
}

extension RepeatGroupRowMapper on RepeatGroupRow {
  RepeatGroup toDomain() => RepeatGroup(
    id: id,
    sessionTemplateId: sessionTemplateId,
    orderIndex: orderIndex,
    repeatCount: repeatCount,
  );
}

extension RepeatGroupMapper on RepeatGroup {
  RepeatGroupRow toRow(DateTime at) => RepeatGroupRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    sessionTemplateId: sessionTemplateId,
    orderIndex: orderIndex,
    repeatCount: repeatCount,
  );
}

extension EnduranceBlockRowMapper on EnduranceBlockRow {
  EnduranceBlock toDomain() => EnduranceBlock(
    id: id,
    sessionTemplateId: sessionTemplateId,
    orderIndex: orderIndex,
    role: role,
    measure: measure,
    targetValue: targetValue,
    repeatGroupId: repeatGroupId,
    intensityLabelId: intensityLabelId,
    notes: notes,
  );
}

extension EnduranceBlockMapper on EnduranceBlock {
  EnduranceBlockRow toRow(DateTime at) => EnduranceBlockRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    sessionTemplateId: sessionTemplateId,
    orderIndex: orderIndex,
    role: role,
    measure: measure,
    targetValue: targetValue,
    repeatGroupId: repeatGroupId,
    intensityLabelId: intensityLabelId,
    notes: notes,
  );
}

extension IntensityLabelRowMapper on IntensityLabelRow {
  IntensityLabel toDomain() =>
      IntensityLabel(id: id, label: label, orderIndex: orderIndex);
}

extension IntensityLabelMapper on IntensityLabel {
  IntensityLabelRow toRow(DateTime at) => IntensityLabelRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    label: label,
    orderIndex: orderIndex,
  );
}

extension WeekOverrideRowMapper on WeekOverrideRow {
  WeekOverride toDomain() => WeekOverride(
    id: id,
    blockId: blockId,
    weekIndex: weekIndex,
    weekday: weekday,
    action: action,
    replacementSessionTemplateId: replacementSessionTemplateId,
    loadMultiplier: loadMultiplier,
  );
}

extension WeekOverrideMapper on WeekOverride {
  WeekOverrideRow toRow(DateTime at) => WeekOverrideRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    blockId: blockId,
    weekIndex: weekIndex,
    weekday: weekday,
    action: action,
    replacementSessionTemplateId: replacementSessionTemplateId,
    loadMultiplier: loadMultiplier,
  );
}

extension OccurrenceMoveRowMapper on OccurrenceMoveRow {
  OccurrenceMove toDomain() => OccurrenceMove(
    id: id,
    blockId: blockId,
    date: date,
    targetDate: targetDate,
  );
}

extension OccurrenceMoveMapper on OccurrenceMove {
  OccurrenceMoveRow toRow(DateTime at) => OccurrenceMoveRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    blockId: blockId,
    date: date,
    targetDate: targetDate,
  );
}

extension SessionLogRowMapper on SessionLogRow {
  SessionLog toDomain() => SessionLog(
    id: id,
    planId: planId,
    date: date,
    status: status,
    blockId: blockId,
    sessionTemplateId: sessionTemplateId,
    startedAt: startedAt,
    completedAt: completedAt,
    totalDurationSeconds: totalDurationSeconds,
    notes: notes,
    plannedSnapshot: plannedSnapshot,
  );
}

extension SessionLogMapper on SessionLog {
  SessionLogRow toRow(DateTime at) => SessionLogRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    planId: planId,
    date: date,
    status: status,
    blockId: blockId,
    sessionTemplateId: sessionTemplateId,
    startedAt: startedAt,
    completedAt: completedAt,
    totalDurationSeconds: totalDurationSeconds,
    notes: notes,
    plannedSnapshot: plannedSnapshot,
  );
}

extension LoggedExerciseRowMapper on LoggedExerciseRow {
  LoggedExercise toDomain() => LoggedExercise(
    id: id,
    sessionLogId: sessionLogId,
    exerciseId: exerciseId,
    orderIndex: orderIndex,
    supersetGroup: supersetGroup,
    skipped: skipped,
    notes: notes,
  );
}

extension LoggedExerciseMapper on LoggedExercise {
  LoggedExerciseRow toRow(DateTime at) => LoggedExerciseRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    sessionLogId: sessionLogId,
    exerciseId: exerciseId,
    orderIndex: orderIndex,
    supersetGroup: supersetGroup,
    skipped: skipped,
    notes: notes,
  );
}

extension LoggedSetRowMapper on LoggedSetRow {
  LoggedSet toDomain() => LoggedSet(
    id: id,
    loggedExerciseId: loggedExerciseId,
    orderIndex: orderIndex,
    kind: kind,
    plannedWeight: plannedWeight,
    plannedReps: plannedReps,
    plannedDurationSeconds: plannedDurationSeconds,
    plannedIntensity: plannedIntensity,
    actualWeight: actualWeight,
    actualReps: actualReps,
    actualDurationSeconds: actualDurationSeconds,
    actualIntensity: actualIntensity,
    completed: completed,
  );
}

extension LoggedSetMapper on LoggedSet {
  LoggedSetRow toRow(DateTime at) => LoggedSetRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    loggedExerciseId: loggedExerciseId,
    orderIndex: orderIndex,
    kind: kind,
    plannedWeight: plannedWeight,
    plannedReps: plannedReps,
    plannedDurationSeconds: plannedDurationSeconds,
    plannedIntensity: plannedIntensity,
    actualWeight: actualWeight,
    actualReps: actualReps,
    actualDurationSeconds: actualDurationSeconds,
    actualIntensity: actualIntensity,
    completed: completed,
  );
}

extension LoggedBlockRowMapper on LoggedBlockRow {
  LoggedBlock toDomain() => LoggedBlock(
    id: id,
    sessionLogId: sessionLogId,
    orderIndex: orderIndex,
    roundIndex: roundIndex,
    role: role,
    measure: measure,
    targetValue: targetValue,
    intensityLabel: intensityLabel,
    actualDurationSeconds: actualDurationSeconds,
    actualDistanceMeters: actualDistanceMeters,
    completed: completed,
  );
}

extension LoggedBlockMapper on LoggedBlock {
  LoggedBlockRow toRow(DateTime at) => LoggedBlockRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    sessionLogId: sessionLogId,
    orderIndex: orderIndex,
    roundIndex: roundIndex,
    role: role,
    measure: measure,
    targetValue: targetValue,
    intensityLabel: intensityLabel,
    actualDurationSeconds: actualDurationSeconds,
    actualDistanceMeters: actualDistanceMeters,
    completed: completed,
  );
}

extension AppSettingsRowMapper on AppSettingsRow {
  AppSettings toDomain() => AppSettings(
    id: id,
    unitWeight: unitWeight,
    unitDistance: unitDistance,
    intensityScale: intensityScale,
    defaultRestSeconds: defaultRestSeconds,
    audioCues: audioCues,
    vibration: vibration,
    themeMode: themeMode,
  );
}

extension AppSettingsMapper on AppSettings {
  AppSettingsRow toRow(DateTime at) => AppSettingsRow(
    id: id,
    createdAt: at,
    updatedAt: at,
    unitWeight: unitWeight,
    unitDistance: unitDistance,
    intensityScale: intensityScale,
    defaultRestSeconds: defaultRestSeconds,
    audioCues: audioCues,
    vibration: vibration,
    themeMode: themeMode,
  );
}
