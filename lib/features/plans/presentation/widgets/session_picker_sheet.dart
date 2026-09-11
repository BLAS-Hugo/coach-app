import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/sheet_parts.dart';
import 'package:coach_app/features/plans/presentation/widgets/template_meta.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What the weekday sheet hands back.
@immutable
sealed class SessionChoice {
  const SessionChoice();
}

/// Put this existing template on the day.
final class SessionChoiceAssign extends SessionChoice {
  const SessionChoiceAssign(this.templateId);

  final String templateId;

  @override
  bool operator ==(Object other) =>
      other is SessionChoiceAssign && other.templateId == templateId;

  @override
  int get hashCode => templateId.hashCode;
}

/// Create a template with this name and put it on the day.
final class SessionChoiceCreate extends SessionChoice {
  const SessionChoiceCreate(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is SessionChoiceCreate && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Make the day a rest day.
final class SessionChoiceRest extends SessionChoice {
  const SessionChoiceRest();

  @override
  bool operator ==(Object other) => other is SessionChoiceRest;

  @override
  int get hashCode => 0;
}

/// Chooses what a weekday holds: one of the plan's sessions, a new one, or
/// rest.
///
/// Sessions belong to the plan rather than to the day (PRD §3), so the
/// list offers every one of them — the same session on Monday and Thursday
/// is one template, not two.
class SessionPickerSheet extends StatefulWidget {
  const SessionPickerSheet({
    required this.weekday,
    required this.templates,
    required this.type,
    this.currentTemplateId,
    super.key,
  });

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  final int weekday;
  final List<SessionTemplateSummary> templates;
  final PlanType type;

  /// The template on the day now, or null for a rest day.
  final String? currentTemplateId;

  static Future<SessionChoice?> show(
    BuildContext context, {
    required int weekday,
    required List<SessionTemplateSummary> templates,
    required PlanType type,
    String? currentTemplateId,
  }) => showPlanSheet<SessionChoice>(
    context,
    SessionPickerSheet(
      weekday: weekday,
      templates: templates,
      type: type,
      currentTemplateId: currentTemplateId,
    ),
  );

  @override
  State<SessionPickerSheet> createState() => _SessionPickerSheetState();
}

class _SessionPickerSheetState extends State<SessionPickerSheet> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(SessionChoiceCreate(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return SheetFrame(
      title: l10n.weekdayLong('${widget.weekday}'),
      children: [
        for (final summary in widget.templates)
          _SheetRow(
            title: summary.template.name,
            meta: templateMeta(l10n, summary, type: widget.type),
            selected: summary.template.id == widget.currentTemplateId,
            onTap: () => Navigator.of(
              context,
            ).pop(SessionChoiceAssign(summary.template.id)),
          ),
        if (widget.currentTemplateId != null)
          _SheetRow(
            title: l10n.sessionPickerRest,
            muted: true,
            onTap: () => Navigator.of(context).pop(const SessionChoiceRest()),
          ),
        if (widget.templates.isNotEmpty || widget.currentTemplateId != null)
          Divider(height: AppSpacing.lg, color: colors.borderSubtle),
        SheetLabel(l10n.sessionPickerNew),
        SheetTextField(
          controller: _name,
          hint: l10n.sessionPickerNewHint,
          // Only when there is nothing to pick: otherwise the keyboard would
          // cover the list it is an alternative to.
          autofocus: widget.templates.isEmpty,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(),
        ),
        const SizedBox(height: AppSpacing.lg),
        SheetActions(
          submitLabel: l10n.sessionPickerCreate,
          onSubmit: _name.text.trim().isEmpty ? null : _create,
        ),
      ],
    );
  }
}

/// One tappable choice: a name, an optional size line, and a check on the
/// session the day holds now.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.title,
    required this.onTap,
    this.meta,
    this.selected = false,
    this.muted = false,
  });

  final String title;
  final String? meta;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final subtitle = meta;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: typography.body.copyWith(
                          fontWeight: muted ? null : FontWeight.w600,
                          color: muted
                              ? colors.textSecondary
                              : colors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: typography.dataSmall.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  ExcludeSemantics(
                    child: Text(
                      '✓',
                      style: typography.body.copyWith(color: colors.stateDone),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
