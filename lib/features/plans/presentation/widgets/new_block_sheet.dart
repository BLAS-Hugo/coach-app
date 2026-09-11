import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/widgets/sheet_parts.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// What the block sheet hands back: everything a first block needs.
@immutable
class NewBlockRequest {
  const NewBlockRequest({
    required this.name,
    required this.startDate,
    required this.durationWeeks,
  });

  final String name;
  final DateOnly startDate;
  final int durationWeeks;

  @override
  bool operator ==(Object other) =>
      other is NewBlockRequest &&
      other.name == name &&
      other.startDate == startDate &&
      other.durationWeeks == durationWeeks;

  @override
  int get hashCode => Object.hash(name, startDate, durationWeeks);
}

/// Creates a plan's first block: a name, a start date and a length (PRD
/// §5.4, step 3).
///
/// Later blocks come from "Dupliquer la semaine", which seeds them from the
/// block before.
class NewBlockSheet extends StatefulWidget {
  const NewBlockSheet({
    required this.today,
    required this.defaultName,
    super.key,
  });

  /// The day the start date defaults to.
  final DateOnly today;
  final String defaultName;

  /// How far either side of [today] a block may start. Back, for a program
  /// already underway when it is entered; forward, for one planned ahead.
  static const int dateWindowDays = 365;

  static const int _defaultWeeks = 4;

  static Future<NewBlockRequest?> show(
    BuildContext context, {
    required DateOnly today,
    required String defaultName,
  }) => showPlanSheet<NewBlockRequest>(
    context,
    NewBlockSheet(today: today, defaultName: defaultName),
  );

  @override
  State<NewBlockSheet> createState() => _NewBlockSheetState();
}

class _NewBlockSheetState extends State<NewBlockSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.defaultName,
  );
  late DateOnly _start = widget.today;
  int _weeks = NewBlockSheet._defaultWeeks;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.toLocalDateTime(),
      firstDate: widget.today
          .addDays(-NewBlockSheet.dateWindowDays)
          .toLocalDateTime(),
      lastDate: widget.today
          .addDays(NewBlockSheet.dateWindowDays)
          .toLocalDateTime(),
    );
    if (picked == null) return;
    setState(() => _start = DateOnly.fromDateTime(picked));
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      NewBlockRequest(name: name, startDate: _start, durationWeeks: _weeks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return SheetFrame(
      title: l10n.newBlockSheetTitle,
      children: [
        SheetLabel(l10n.newBlockNameLabel),
        SheetTextField(
          controller: _name,
          hint: widget.defaultName,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        SheetLabel(l10n.newBlockStartLabel),
        Material(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: _pickStart,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              height: AppTouchTarget.min,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                DateFormat.yMMMMEEEEd(locale).format(_start.toLocalDateTime()),
                style: typography.dataBody,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SheetLabel(l10n.newBlockDurationLabel),
        WeeksStepper(
          value: _weeks,
          onChanged: (weeks) => setState(() => _weeks = weeks),
        ),
        const SizedBox(height: AppSpacing.lg),
        SheetActions(
          submitLabel: l10n.newBlockSubmit,
          onSubmit: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
