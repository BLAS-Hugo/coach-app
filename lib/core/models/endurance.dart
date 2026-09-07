/// What an endurance block is for within its session.
enum EnduranceBlockRole { warmup, work, recovery, cooldown }

/// Whether an endurance block targets a time or a distance.
///
/// The app cannot measure distance in V1 — there is no GPS — so distance
/// blocks are advanced by the user (PRD §5.3).
enum EnduranceMeasure {
  /// The block's target value is seconds.
  duration,

  /// The block's target value is metres.
  distance,
}
