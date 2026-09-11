import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Opens [sheet] as a modal bottom sheet in the app's sheet style.
///
/// The sheet paints its own raised surface through [SheetFrame], so the
/// route's own background is cleared.
Future<T?> showPlanSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => sheet,
  );
}

/// The raised surface every plan sheet sits on: top corners rounded, a
/// title, then [children].
///
/// Lifts itself clear of the keyboard, so a sheet with a text field needs
/// nothing of its own for that.
class SheetFrame extends StatelessWidget {
  const SheetFrame({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceRaised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.typography.headingL),
              const SizedBox(height: AppSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A field caption: uppercase `label`, muted.
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: context.typography.label.copyWith(
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}

/// A single-line text field on the sunken surface.
class SheetTextField extends StatelessWidget {
  const SheetTextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      style: typography.body,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: typography.body.copyWith(color: colors.textMuted),
        filled: true,
        fillColor: colors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: border(colors.borderSubtle),
        enabledBorder: border(colors.borderSubtle),
        focusedBorder: border(colors.borderStrong),
      ),
    );
  }
}

/// Cancel on the left, the filled primary on the right.
///
/// A null [onSubmit] disables the primary — the sheet has nothing valid to
/// hand back yet.
class SheetActions extends StatelessWidget {
  const SheetActions({
    required this.submitLabel,
    required this.onSubmit,
    super.key,
  });

  final String submitLabel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final enabled = onSubmit != null;

    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.sheetCancel,
              style: typography.body.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Material(
            color: enabled ? colors.textPrimary : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              onTap: onSubmit,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: SizedBox(
                height: AppTouchTarget.primary,
                child: Center(
                  child: Text(
                    submitLabel,
                    style: typography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? colors.onAccent : colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `−  5 semaines  +`, bounded by [min] and [max].
///
/// The stepper of runner screen 3a, sized for a sheet: 48 × 48 buttons on
/// the sunken surface either side of the value.
class WeeksStepper extends StatelessWidget {
  const WeeksStepper({
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 52,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        _StepButton(
          glyph: '−',
          label: l10n.stepperDecrease,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Container(
            height: AppTouchTarget.min,
            alignment: Alignment.center,
            decoration: _stepDecoration(context),
            child: Text(
              l10n.blockDurationWeeks(value),
              style: context.typography.dataBody,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _StepButton(
          glyph: '+',
          label: l10n.stepperIncrease,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

BoxDecoration _stepDecoration(BuildContext context) => BoxDecoration(
  color: context.colors.surfaceSunken,
  borderRadius: BorderRadius.circular(AppRadii.md),
  border: Border.all(color: context.colors.borderSubtle),
);

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: const Color(0x00000000),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: AppTouchTarget.min,
              height: AppTouchTarget.min,
              alignment: Alignment.center,
              decoration: _stepDecoration(context),
              child: Text(
                glyph,
                style: context.typography.dataBody.copyWith(
                  color: onTap == null ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
