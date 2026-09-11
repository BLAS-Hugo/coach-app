import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/features/plans/presentation/widgets/sheet_parts.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// "Durée du bloc": a length in weeks, never shorter than [min].
///
/// [min] is what keeps a running block from being shortened into the past
/// — the earliest it may end is the week in progress.
class BlockDurationSheet extends StatefulWidget {
  const BlockDurationSheet({
    required this.initialWeeks,
    this.min = 1,
    super.key,
  });

  final int initialWeeks;
  final int min;

  /// Resolves to the chosen length, or null if dismissed.
  static Future<int?> show(
    BuildContext context, {
    required int initialWeeks,
    int min = 1,
  }) => showPlanSheet<int>(
    context,
    BlockDurationSheet(initialWeeks: initialWeeks, min: min),
  );

  @override
  State<BlockDurationSheet> createState() => _BlockDurationSheetState();
}

class _BlockDurationSheetState extends State<BlockDurationSheet> {
  late int _weeks = widget.initialWeeks < widget.min
      ? widget.min
      : widget.initialWeeks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetFrame(
      title: l10n.weekTemplateDuration,
      children: [
        WeeksStepper(
          value: _weeks,
          min: widget.min,
          onChanged: (weeks) => setState(() => _weeks = weeks),
        ),
        const SizedBox(height: AppSpacing.lg),
        SheetActions(
          submitLabel: l10n.sheetConfirm,
          onSubmit: () => Navigator.of(context).pop(_weeks),
        ),
      ],
    );
  }
}
