import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The filled plan-type badge: a square **F** for force, a round **E** for
/// endurance.
///
/// The shape carries the type as much as the colour does, so the two stay
/// apart without colour — the handoff's non-colour backup for
/// deuteranopia and greyscale. The letter is excluded from semantics; the
/// type label beside the badge is what gets read out.
class PlanTypeBadge extends StatelessWidget {
  const PlanTypeBadge({required this.isStrength, this.size = 22, super.key});

  final bool isStrength;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentFor(isStrength: isStrength),
        borderRadius: BorderRadius.circular(
          isStrength ? AppRadii.sm : AppRadii.pill,
        ),
      ),
      child: ExcludeSemantics(
        child: Text(
          isStrength
              ? l10n.planTypeStrengthInitial
              : l10n.planTypeEnduranceInitial,
          style: context.typography.dataSmall.copyWith(
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w600,
            color: colors.onAccent,
          ),
        ),
      ),
    );
  }
}
