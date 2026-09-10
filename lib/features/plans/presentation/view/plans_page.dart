import 'package:coach_app/app/di/injector.dart';
import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/repositories/repositories.dart';
import 'package:coach_app/features/plans/presentation/bloc/plan_list_bloc.dart';
import 'package:coach_app/features/plans/presentation/widgets/widgets.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The plan list (PRD §5.4, design screen 4a).
///
/// The *Réglages* rows the design draws under the list belong to M4 and are
/// deliberately absent; "Sauvegarde locale" is a V1 non-goal and will not
/// appear at all.
class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PlanListBloc(getIt<PlanRepository>())
            ..add(const PlanListSubscriptionRequested()),
      child: const PlansView(),
    );
  }
}

/// Everything of the plan list that does not depend on where the bloc came
/// from, so a widget test can drive it with a bloc of its own.
class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                context.l10n.programTitle,
                style: context.typography.headingL,
              ),
            ),
            const Expanded(child: _PlanListBody()),
          ],
        ),
      ),
    );
  }
}

class _PlanListBody extends StatelessWidget {
  const _PlanListBody();

  Future<void> _createPlan(BuildContext context) async {
    // Read the bloc before the await: the sheet's context is gone by the
    // time it resolves.
    final bloc = context.read<PlanListBloc>();
    final request = await NewPlanSheet.show(context);
    if (request == null) return;
    bloc.add(PlanListPlanCreated(name: request.name, type: request.type));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlanListBloc, PlanListState>(
      builder: (context, state) {
        switch (state.status) {
          case PlanListStatus.initial:
          case PlanListStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case PlanListStatus.failure:
            return _Message(text: context.l10n.plansLoadError);
          case PlanListStatus.success:
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                if (state.isEmpty)
                  const _EmptyState()
                else
                  for (final summary in state.summaries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PlanCard(summary: summary),
                    ),
                NewPlanButton(onPressed: () => _createPlan(context)),
              ],
            );
        }
      },
    );
  }
}

/// Shown before the first plan exists. The dashed button below it is the
/// only way forward, so the copy says what a plan buys rather than
/// repeating the button's label.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
      child: Column(
        children: [
          Text(l10n.plansEmptyTitle, style: typography.headingM),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.plansEmptyMessage,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(color: colors.textSecondary),
          ),
        ],
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
