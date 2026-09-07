import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan.freezed.dart';

/// Whether a plan schedules strength sessions or endurance sessions.
///
/// Fixed at creation (PRD §5.4). One active plan of each type may run
/// concurrently, which is why a day can show two sessions.
enum PlanType { strength, endurance }

/// A named training program: a container for an ordered list of training
/// blocks.
///
/// A plan carries no dates of its own — its blocks do (PRD §3). Session
/// templates belong to the plan rather than to a block, so a later block can
/// reuse them when the user duplicates a week.
@freezed
abstract class Plan with _$Plan {
  const factory Plan({
    required String id,
    required String name,
    required PlanType type,
    String? notes,
  }) = _Plan;
}
