import 'dart:math' as math;

import 'package:coach_app/app/di/injector.dart';
import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/features/plans/presentation/bloc/week_template_bloc.dart';
import 'package:coach_app/features/plans/presentation/widgets/widgets.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The weekly template of one training block (PRD §5.4, design screen 4b).
///
/// "On édite une semaine type, pas un calendrier": seven weekdays, repeated
/// for every week the block lasts. Saved as it is edited; "Annuler" in the
/// header is the way back.
class WeekTemplatePage extends StatelessWidget {
  const WeekTemplatePage({
    required this.planId,
    required this.onOpenBlock,
    this.blockId,
    super.key,
  });

  final String planId;

  /// The block to open, or null for the one the plan is on now.
  final String? blockId;

  /// Opens another block's week in place of this one — where "Dupliquer la
  /// semaine" leads. Routing lives with the caller.
  final ValueChanged<String> onOpenBlock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WeekTemplateBloc(
        getIt<PlanRepository>(),
        planId: planId,
        blockId: blockId,
      )..add(const WeekTemplateSubscriptionRequested()),
      child: WeekTemplateView(onOpenBlock: onOpenBlock),
    );
  }
}

/// Everything of the screen that does not depend on where the bloc came
/// from, so a widget test can drive it with a bloc of its own.
class WeekTemplateView extends StatelessWidget {
  const WeekTemplateView({required this.onOpenBlock, super.key});

  final ValueChanged<String> onOpenBlock;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WeekTemplateBloc, WeekTemplateState>(
          listenWhen: (previous, current) =>
              current.error != null && previous.error != current.error,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(_errorText(context, state.error!))),
            ),
        ),
        BlocListener<WeekTemplateBloc, WeekTemplateState>(
          listenWhen: (previous, current) =>
              current.duplicatedBlockId != null &&
              previous.duplicatedBlockId != current.duplicatedBlockId,
          listener: (context, state) => onOpenBlock(state.duplicatedBlockId!),
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<WeekTemplateBloc, WeekTemplateState>(
            builder: (context, state) => switch (state.status) {
              WeekTemplateStatus.initial || WeekTemplateStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              WeekTemplateStatus.failure => _Message(
                text: context.l10n.weekTemplateLoadError,
              ),
              WeekTemplateStatus.notFound => _Message(
                text: context.l10n.weekTemplateNotFound,
              ),
              WeekTemplateStatus.success => _Loaded(
                week: state.week!,
                canUndo: state.canUndo,
              ),
            },
          ),
        ),
      ),
    );
  }

  String _errorText(BuildContext context, WeekTemplateError error) =>
      switch (error) {
        WeekTemplateError.blockOverlap => context.l10n.weekTemplateErrorOverlap,
        WeekTemplateError.planConflict =>
          context.l10n.weekTemplateErrorPlanConflict,
        WeekTemplateError.unknown => context.l10n.weekTemplateErrorUnknown,
      };
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.week, required this.canUndo});

  final WeekTemplate week;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    final stopDate = week.stopDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(week: week, canUndo: canUndo),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              _Title(week: week),
              const SizedBox(height: AppSpacing.md),
              if (week.block == null)
                _NoBlock(week: week)
              else ...[
                _Days(week: week),
                _BlockSection(week: week),
              ],
            ],
          ),
        ),
        if (stopDate != null) const _StopBar(),
      ],
    );
  }
}

/// `‹  [F]  FORCE · BLOC 2 ................  Annuler`
class _Header extends StatelessWidget {
  const _Header({required this.week, required this.canUndo});

  final WeekTemplate week;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;
    final isStrength = week.plan.type == PlanType.strength;
    final type = isStrength ? l10n.planTypeStrength : l10n.planTypeEndurance;
    final ordinal = week.blockOrdinal;
    final label = ordinal == null
        ? type
        : l10n.weekTemplateHeader(type, ordinal);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.xs),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.navigateBack,
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: SizedBox(
                  width: AppTouchTarget.min,
                  height: AppTouchTarget.min,
                  child: Center(
                    child: Text(
                      '‹',
                      style: typography.headingL.copyWith(
                        height: 1,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PlanTypeBadge(isStrength: isStrength, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              label: label,
              child: ExcludeSemantics(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: typography.label.copyWith(
                    color: colors.accentFor(isStrength: isStrength),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: canUndo
                ? () => context.read<WeekTemplateBloc>().add(
                    const WeekTemplateUndoRequested(),
                  )
                : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
            ),
            child: Text(
              l10n.weekTemplateUndo,
              style: typography.label.copyWith(
                letterSpacing: 0,
                color: canUndo ? colors.textSecondary : colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Semaine type", and under it the line saying what the week amounts to
/// and from when edits apply.
class _Title extends StatelessWidget {
  const _Title({required this.week});

  final WeekTemplate week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;
    final block = week.block;

    final weeks = block?.weekCount;
    final status = block == null
        ? null
        : [
            l10n.weekTemplateSessionCount(week.slots.length),
            if (weeks == null)
              l10n.weekTemplateRepeatedOngoing
            else
              l10n.weekTemplateRepeatedWeeks(weeks),
            if (week.isEditable)
              l10n.weekTemplateAppliesFromToday
            else
              l10n.weekTemplateFinished,
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.weekTemplateTitle, style: typography.headingL),
          if (status != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              status,
              style: typography.dataSmall.copyWith(
                fontSize: 11.5,
                color: colors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days({required this.week});

  final WeekTemplate week;

  Future<void> _openDay(BuildContext context, int weekday) async {
    // Read the bloc before the await: the sheet's context is gone by the
    // time it resolves.
    final bloc = context.read<WeekTemplateBloc>();
    final choice = await SessionPickerSheet.show(
      context,
      weekday: weekday,
      templates: week.templates,
      type: week.plan.type,
      currentTemplateId: week.slotOn(weekday)?.sessionTemplateId,
    );
    switch (choice) {
      case null:
        return;
      case SessionChoiceAssign(:final templateId):
        bloc.add(
          WeekTemplateSessionAssigned(weekday: weekday, templateId: templateId),
        );
      case SessionChoiceCreate(:final name):
        bloc.add(WeekTemplateSessionCreated(weekday: weekday, name: name));
      case SessionChoiceRest():
        bloc.add(WeekTemplateDayCleared(weekday: weekday));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.colors.accentFor(
      isStrength: week.plan.type == PlanType.strength,
    );

    return Column(
      children: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        )
          Builder(
            builder: (context) {
              final slot = week.slotOn(weekday);
              final template = slot == null
                  ? null
                  : week.templateById(slot.sessionTemplateId);
              return WeekDayRow(
                weekday: weekday,
                accent: accent,
                editable: week.isEditable,
                sessionName: template?.template.name,
                sessionMeta: template == null
                    ? null
                    : templateMeta(l10n, template, type: week.plan.type),
                isLast: weekday == DateTime.sunday,
                onTap: () => _openDay(context, weekday),
                onSessionDropped: (from) => context
                    .read<WeekTemplateBloc>()
                    .add(WeekTemplateSessionMoved(from: from, to: weekday)),
              );
            },
          ),
      ],
    );
  }
}

/// "Bloc": its length, and the step into the next one.
class _BlockSection extends StatelessWidget {
  const _BlockSection({required this.week});

  final WeekTemplate week;

  Future<void> _changeDuration(BuildContext context) async {
    final bloc = context.read<WeekTemplateBloc>();
    final min = week.minDurationWeeks;
    final weeks = await BlockDurationSheet.show(
      context,
      initialWeeks: math.max(week.block?.weekCount ?? min, min),
      min: min,
    );
    if (weeks == null) return;
    bloc.add(WeekTemplateDurationChanged(weeks: weeks));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weeks = week.block?.weekCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetLabel(l10n.weekTemplateBlockSection),
          _SettingRow(
            label: l10n.weekTemplateDuration,
            value: weeks == null
                ? l10n.blockDurationOngoing
                : l10n.blockDurationWeeks(weeks),
            onTap: week.isEditable ? () => _changeDuration(context) : null,
          ),
          _SettingRow(
            label: l10n.weekTemplateDuplicate,
            value: l10n.weekTemplateDuplicateHint,
            muted: true,
            isLast: true,
            onTap: week.canDuplicate
                ? () => context.read<WeekTemplateBloc>().add(
                    WeekTemplateWeekDuplicated(
                      name: l10n.blockDefaultName(week.blocks.length + 1),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// A 52-high settings line: label, value, `›`. Inert without [onTap].
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.isLast = false,
  });

  /// The design's settings line, between the 48 floor and the 56 primary.
  static const double _height = 52;

  final String label;
  final String value;
  final bool muted;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final enabled = onTap != null;
    final border = BorderSide(color: colors.borderSubtle);

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            border: Border(
              top: border,
              bottom: isLast ? border : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typography.body.copyWith(
                    height: 20 / 15,
                    color: enabled ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
              Text(
                value,
                style: typography.dataSmall.copyWith(
                  fontSize: muted ? 12 : 13,
                  color: muted || !enabled
                      ? colors.textMuted
                      : colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: Text(
                  '›',
                  style: typography.body.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plan with no block yet: what a block is, and the way to make one.
class _NoBlock extends StatelessWidget {
  const _NoBlock({required this.week});

  final WeekTemplate week;

  Future<void> _createBlock(BuildContext context) async {
    final bloc = context.read<WeekTemplateBloc>();
    final request = await NewBlockSheet.show(
      context,
      today: week.today,
      defaultName: context.l10n.blockDefaultName(week.blocks.length + 1),
    );
    if (request == null) return;
    bloc.add(
      WeekTemplateBlockCreated(
        name: request.name,
        startDate: request.startDate,
        durationWeeks: request.durationWeeks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.weekTemplateNoBlockTitle, style: typography.headingM),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.weekTemplateNoBlockMessage,
            style: typography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _OutlinedAction(
            label: l10n.weekTemplateCreateBlock,
            onPressed: () => _createBlock(context),
          ),
        ],
      ),
    );
  }
}

/// The pinned action bar: "Arrêter le bloc après cette semaine".
///
/// Outlined rather than filled — ending a block is not the screen's
/// primary purpose, and "Annuler" takes it back, so it needs no dialog.
class _StopBar extends StatelessWidget {
  const _StopBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: _OutlinedAction(
          label: context.l10n.weekTemplateStop,
          onPressed: () => context.read<WeekTemplateBloc>().add(
            const WeekTemplateBlockStopped(),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

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
          height: AppTouchTarget.primary,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Text(
            label,
            style: context.typography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.typography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
