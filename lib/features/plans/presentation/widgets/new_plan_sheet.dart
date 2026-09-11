import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/sheet_parts.dart';
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
  static Future<NewPlanRequest?> show(BuildContext context) =>
      showPlanSheet<NewPlanRequest>(context, const NewPlanSheet());

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
    final l10n = context.l10n;

    return SheetFrame(
      title: l10n.newPlanSheetTitle,
      children: [
        SheetLabel(l10n.newPlanNameLabel),
        SheetTextField(
          controller: _name,
          hint: l10n.newPlanNameHint,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        SheetLabel(l10n.newPlanTypeLabel),
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
        SheetActions(
          submitLabel: l10n.newPlanSubmit,
          // A plan is found by its name and nothing else, so a blank one
          // cannot be created.
          onSubmit: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
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
