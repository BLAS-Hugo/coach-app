import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What the creation sheet hands back: everything needed to make a plan.
///
/// The type is part of it because a plan's type is fixed at creation and
/// never editable afterwards (PRD §5.4) — asking later would be too late.
@immutable
class NewPlanRequest {
  const NewPlanRequest({required this.name, required this.type});

  final String name;
  final PlanType type;

  @override
  bool operator ==(Object other) =>
      other is NewPlanRequest && other.name == name && other.type == type;

  @override
  int get hashCode => Object.hash(name, type);
}

/// The "+ Nouveau plan" sheet: a name and a type, and nothing else.
///
/// Blocks and the weekly template are edited afterwards, on their own
/// screens; a plan with neither is a valid, if empty, plan.
class NewPlanSheet extends StatefulWidget {
  const NewPlanSheet({super.key});

  /// Opens the sheet and resolves to the request, or null if dismissed.
  static Future<NewPlanRequest?> show(BuildContext context) {
    return showModalBottomSheet<NewPlanRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0x00000000),
      builder: (_) => const NewPlanSheet(),
    );
  }

  @override
  State<NewPlanSheet> createState() => _NewPlanSheetState();
}

class _NewPlanSheetState extends State<NewPlanSheet> {
  final TextEditingController _name = TextEditingController();
  PlanType _type = PlanType.strength;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(NewPlanRequest(name: name, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Padding(
      // Lifts the sheet clear of the keyboard the name field summons.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newPlanSheetTitle, style: typography.headingL),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.newPlanNameLabel.toUpperCase(),
                style: typography.label.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                style: typography.body,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l10n.newPlanNameHint,
                  hintStyle: typography.body.copyWith(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: colors.borderStrong),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.newPlanTypeLabel.toUpperCase(),
                style: typography.label.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _TypeOption(
                      label: l10n.planTypeStrength,
                      accent: colors.accentStrength,
                      selected: _type == PlanType.strength,
                      onTap: () => setState(() => _type = PlanType.strength),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _TypeOption(
                      label: l10n.planTypeEndurance,
                      accent: colors.accentEndurance,
                      selected: _type == PlanType.endurance,
                      onTap: () => setState(() => _type = PlanType.endurance),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.newPlanCancel,
                        style: typography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SubmitButton(
                      label: l10n.newPlanSubmit,
                      // A plan is found by its name and nothing else, so a
                      // blank one cannot be created.
                      onPressed: _name.text.trim().isEmpty ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two plan types, chosen once and for good.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: const Color(0x00000000),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              height: AppTouchTarget.min,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.accentWash(accent) : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: selected ? accent : colors.borderSubtle,
                ),
              ),
              child: Text(
                label.toUpperCase(),
                style: context.typography.label.copyWith(
                  color: selected ? accent : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet's primary action: filled, and the only filled button on it.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    return Material(
      color: enabled ? colors.textPrimary : colors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          height: AppTouchTarget.primary,
          child: Center(
            child: Text(
              label,
              style: context.typography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: enabled ? colors.onAccent : colors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
