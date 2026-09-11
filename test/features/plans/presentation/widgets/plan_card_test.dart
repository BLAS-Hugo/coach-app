import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/widgets/plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  const strengthPlan = Plan(
    id: 'p1',
    name: 'Haut / bas',
    type: PlanType.strength,
  );
  const endurancePlan = Plan(
    id: 'p2',
    name: 'Base + fractionné',
    type: PlanType.endurance,
  );

  final block = TrainingBlock(
    id: 'b1',
    planId: 'p1',
    name: 'intensification',
    orderIndex: 1,
    startDate: DateOnly(2026, 3, 2),
    durationWeeks: 5,
  );

  PlanSummary activeSummary({
    Plan plan = strengthPlan,
    int sessionsPerWeek = 4,
    int? weekCount = 5,
  }) {
    return PlanSummary(
      plan: plan,
      blockCount: 3,
      currentBlock: block,
      currentBlockOrdinal: 2,
      weekIndex: 2,
      weekCount: weekCount,
      sessionsPerWeek: sessionsPerWeek,
    );
  }

  /// Every box the rail draws, in order, ignoring the spacers between them.
  List<BoxDecoration> railSegments(WidgetTester tester) {
    return tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(PlanCard),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where(
          (decoration) => decoration.borderRadius == BorderRadius.circular(2),
        )
        .toList();
  }

  group('PlanCard', () {
    testWidgets('renders a strength plan the way the design reads it', (
      tester,
    ) async {
      await tester.pumpApp(PlanCard(summary: activeSummary()));

      expect(find.text('F'), findsOneWidget);
      expect(find.text('FORCE'), findsOneWidget);
      expect(find.text('actif'), findsOneWidget);
      expect(find.text('Haut / bas — 4 séances'), findsOneWidget);
      expect(
        find.text('bloc 2 « intensification » · semaine 3 / 5'),
        findsOneWidget,
      );
      expect(find.text('Semaine type'), findsOneWidget);
      expect(find.text('Blocs'), findsOneWidget);
    });

    testWidgets('calls an endurance plan\'s sessions "sorties"', (
      tester,
    ) async {
      await tester.pumpApp(
        PlanCard(
          summary: activeSummary(plan: endurancePlan, sessionsPerWeek: 3),
        ),
      );

      expect(find.text('E'), findsOneWidget);
      expect(find.text('ENDURANCE'), findsOneWidget);
      expect(find.text('Base + fractionné — 3 sorties'), findsOneWidget);
    });

    testWidgets('singularises a one-session week', (tester) async {
      await tester.pumpApp(
        PlanCard(summary: activeSummary(sessionsPerWeek: 1)),
      );

      expect(find.text('Haut / bas — 1 séance'), findsOneWidget);
    });

    testWidgets('singularises a one-outing week', (tester) async {
      await tester.pumpApp(
        PlanCard(
          summary: activeSummary(plan: endurancePlan, sessionsPerWeek: 1),
        ),
      );

      expect(find.text('Base + fractionné — 1 sortie'), findsOneWidget);
    });

    testWidgets('shows the bare name when nothing is scheduled', (
      tester,
    ) async {
      await tester.pumpApp(
        PlanCard(summary: activeSummary(sessionsPerWeek: 0)),
      );

      expect(find.text('Haut / bas'), findsOneWidget);
    });

    testWidgets('drops the week total for an ongoing block', (tester) async {
      await tester.pumpApp(PlanCard(summary: activeSummary(weekCount: null)));

      expect(
        find.text('bloc 2 « intensification » · semaine 3'),
        findsOneWidget,
      );
      // No total means no rail: there is nothing to divide into segments.
      expect(railSegments(tester), isEmpty);
    });

    testWidgets('says so when no block is running', (tester) async {
      await tester.pumpApp(
        const PlanCard(summary: PlanSummary(plan: strengthPlan, blockCount: 2)),
      );

      expect(find.text('aucun bloc en cours'), findsOneWidget);
      expect(find.text('actif'), findsNothing);
      expect(railSegments(tester), isEmpty);
    });

    testWidgets('fills the rail up to the week in progress', (tester) async {
      await tester.pumpApp(PlanCard(summary: activeSummary()));

      final segments = railSegments(tester);
      expect(segments, hasLength(5));

      const accent = AppColors.dark;
      final strength = accent.accentStrength;

      // Weeks 1 and 2 are behind: filled, no outline.
      expect(segments[0].color, strength);
      expect(segments[1].color, strength);
      expect(segments[0].border, isNull);
      // Week 3 is in progress: outlined in the accent, not filled.
      expect(segments[2].color, isNull);
      expect(segments[2].border, Border.all(color: strength));
      // Weeks 4 and 5 are ahead: outlined faintly.
      expect(segments[3].border, Border.all(color: accent.borderSubtle));
      expect(segments[4].border, Border.all(color: accent.borderSubtle));
    });

    testWidgets('reports its actions', (tester) async {
      var weekTemplate = 0;
      var blocks = 0;

      await tester.pumpApp(
        PlanCard(
          summary: activeSummary(),
          onWeekTemplate: () => weekTemplate++,
          onBlocks: () => blocks++,
        ),
      );

      await tester.tap(find.text('Semaine type'));
      await tester.tap(find.text('Blocs'));

      expect(weekTemplate, 1);
      expect(blocks, 1);
    });

    testWidgets('stays inert while an action has nowhere to go', (
      tester,
    ) async {
      await tester.pumpApp(PlanCard(summary: activeSummary()));

      await tester.tap(find.text('Semaine type'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
