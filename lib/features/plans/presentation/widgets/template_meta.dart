import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/l10n/l10n.dart';

/// The one-line size of a session: "6 exercices · 24 séries" for strength,
/// "7 blocs" for endurance, "séance vide" before anything is in it.
String templateMeta(
  AppLocalizations l10n,
  SessionTemplateSummary summary, {
  required PlanType type,
}) {
  if (summary.isEmpty) return l10n.templateEmpty;
  return switch (type) {
    PlanType.strength => [
      l10n.templateExerciseCount(summary.exerciseCount),
      l10n.templateSetCount(summary.setCount),
    ].join(' · '),
    PlanType.endurance => l10n.templateEnduranceBlockCount(
      summary.enduranceBlockCount,
    ),
  };
}
