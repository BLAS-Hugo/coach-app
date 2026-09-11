import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/plan_type_badge.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One plan on the plan list (design screen 4a).
///
/// Renders only what [PlanSummary] already holds — the "bloc 2 « … » ·
/// semaine 3 / 5" readout is projected in the repository, so nothing here
/// does date arithmetic.
///
/// The two actions are optional because their destinations arrive in later
/// M2 slices: the design draws them on every card, so they are always
/// rendered, and a null callback simply makes one inert for now.
class PlanCard extends StatelessWidget {
  const PlanCard({
    required this.summary,
    this.onWeekTemplate,
    this.onBlocks,
    super.key,
  });

  /// Height of one week segment in the progress rail.
  static const double _railHeight = 6;

  /// Corner of a week segment. `AppRadii.sm` on a 6px-tall bar would read as
  /// a pill, which is the shape the design reserves for the endurance badge.
  static const double _railRadius = 2;

  final PlanSummary summary;
  final VoidCallback? onWeekTemplate;
  final VoidCallback? onBlocks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isStrength = summary.plan.type == PlanType.strength;
    final accent = colors.accentFor(isStrength: isStrength);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            isStrength: isStrength,
            accent: accent,
            isActive: summary.isActive,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _title(context, isStrength: isStrength),
            style: context.typography.headingM,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _subtitle(context),
            style: context.typography.dataSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          _WeekRail(summary: summary, accent: accent),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: context.l10n.planCardWeekTemplateAction,
                  emphasised: true,
                  onPressed: onWeekTemplate,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _CardAction(
                  label: context.l10n.planCardBlocksAction,
                  emphasised: false,
                  onPressed: onBlocks,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Haut / bas — 4 séances", or the bare plan name while no template
  /// schedules anything.
  String _title(BuildContext context, {required bool isStrength}) {
    final name = summary.plan.name;
    final count = summary.sessionsPerWeek;
    if (count == 0) return name;
    return isStrength
        ? context.l10n.planCardStrengthSessions(name, count)
        : context.l10n.planCardEnduranceSessions(name, count);
  }

  String _subtitle(BuildContext context) {
    final block = summary.currentBlock;
    final ordinal = summary.currentBlockOrdinal;
    final weekIndex = summary.weekIndex;
    if (block == null || ordinal == null || weekIndex == null) {
      return context.l10n.planCardNoActiveBlock;
    }
    // The card reads 1-based; weekIndex counts from 0.
    final weeks = summary.weekCount;
    return weeks == null
        ? context.l10n.planCardBlockProgressOngoing(
            ordinal,
            block.name,
            weekIndex + 1,
          )
        : context.l10n.planCardBlockProgress(
            ordinal,
            block.name,
            weekIndex + 1,
            weeks,
          );
  }
}

/// Badge, plan type and the `actif` marker, on one line.
class _Header extends StatelessWidget {
  const _Header({
    required this.isStrength,
    required this.accent,
    required this.isActive,
  });

  final bool isStrength;
  final Color accent;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;
    final label = isStrength ? l10n.planTypeStrength : l10n.planTypeEndurance;

    return Row(
      children: [
        PlanTypeBadge(isStrength: isStrength),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Semantics(
            label: label,
            child: ExcludeSemantics(
              child: Text(
                label.toUpperCase(),
                style: typography.label.copyWith(color: accent),
              ),
            ),
          ),
        ),
        if (isActive)
          Text(
            l10n.planCardActiveBadge,
            style: typography.dataSmall.copyWith(
              fontSize: 11,
              height: 1,
              color: colors.textMuted,
            ),
          ),
      ],
    );
  }
}

/// One segment per week of the current block: filled behind, outlined in the
/// accent for the week in progress, outlined faintly ahead.
///
/// Nothing is drawn for a plan with no running block, or for an ongoing
/// block, which has no week count to divide into segments.
class _WeekRail extends StatelessWidget {
  const _WeekRail({required this.summary, required this.accent});

  final PlanSummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final weeks = summary.weekCount;
    final current = summary.weekIndex;
    if (weeks == null || current == null) return const SizedBox.shrink();

    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: PlanCard._railHeight,
        child: Row(
          children: [
            for (var week = 0; week < weeks; week++) ...[
              if (week > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PlanCard._railRadius),
                    color: week < current ? accent : null,
                    border: week < current
                        ? null
                        : Border.all(
                            color: week == current
                                ? accent
                                : colors.borderSubtle,
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the two outlined actions at the foot of a card.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.emphasised,
    required this.onPressed,
  });

  final String label;

  /// The primary of the pair: a stronger outline and full-strength text.
  final bool emphasised;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          height: AppTouchTarget.min,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: emphasised ? colors.borderStrong : colors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: context.typography.body.copyWith(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w600,
              color: emphasised ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
