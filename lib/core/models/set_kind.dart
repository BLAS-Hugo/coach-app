/// What a planned or logged set measures, and therefore which of its value
/// fields mean anything (PRD §4.2).
///
/// A fourth kind, `weightDuration` (weighted carries and planks), was
/// specified and then cut by decision: it widens the notation column on
/// every screen it can appear on. Appending a kind later is additive and
/// needs no migration, so nothing is foreclosed.
enum SetKind {
  /// Weight and reps: `80 kg × 5`.
  weightReps,

  /// Reps only: `12 pull-ups`.
  reps,

  /// Seconds only: `45 s plank`.
  duration,
}
