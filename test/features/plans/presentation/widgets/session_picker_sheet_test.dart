import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/session_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  const templates = [
    SessionTemplateSummary(
      template: SessionTemplate(id: 't1', planId: 'p1', name: 'Haut'),
      exerciseCount: 6,
      setCount: 24,
    ),
    SessionTemplateSummary(
      template: SessionTemplate(id: 't2', planId: 'p1', name: 'Bas'),
    ),
  ];

  /// Opens the sheet from a button and hands back what it resolved to.
  Future<List<SessionChoice?>> open(
    WidgetTester tester, {
    List<SessionTemplateSummary> templates = templates,
    String? currentTemplateId,
  }) async {
    final results = <SessionChoice?>[];
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await SessionPickerSheet.show(
              context,
              weekday: DateTime.wednesday,
              templates: templates,
              type: PlanType.strength,
              currentTemplateId: currentTemplateId,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('SessionChoice', () {
    test('compares by value', () {
      expect(const SessionChoiceAssign('t1'), const SessionChoiceAssign('t1'));
      expect(
        const SessionChoiceAssign('t1').hashCode,
        const SessionChoiceAssign('t1').hashCode,
      );
      expect(const SessionChoiceCreate('a'), const SessionChoiceCreate('a'));
      expect(
        const SessionChoiceCreate('a').hashCode,
        const SessionChoiceCreate('a').hashCode,
      );
      expect(const SessionChoiceRest(), const SessionChoiceRest());
      expect(
        const SessionChoiceRest().hashCode,
        const SessionChoiceRest().hashCode,
      );
      expect(const SessionChoiceAssign('t1'), isNot(const SessionChoiceRest()));
    });
  });

  group('SessionPickerSheet', () {
    testWidgets('is titled with the day and lists every session', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Mercredi'), findsOneWidget);
      expect(find.text('Haut'), findsOneWidget);
      expect(find.text('6 exercices · 24 séries'), findsOneWidget);
      expect(find.text('Bas'), findsOneWidget);
      expect(find.text('séance vide'), findsOneWidget);
      // A rest day has nothing to clear.
      expect(find.text('Mettre en repos'), findsNothing);
    });

    testWidgets('picking a session hands it back', (tester) async {
      final results = await open(tester);

      await tester.tap(find.text('Bas'));
      await tester.pumpAndSettle();

      expect(results, [const SessionChoiceAssign('t2')]);
    });

    testWidgets("checks the day's session and offers rest", (tester) async {
      final results = await open(tester, currentTemplateId: 't1');

      expect(find.text('✓'), findsOneWidget);
      await tester.tap(find.text('Mettre en repos'));
      await tester.pumpAndSettle();

      expect(results, [const SessionChoiceRest()]);
    });

    testWidgets('creates a session from a name', (tester) async {
      final results = await open(tester);

      await tester.enterText(find.byType(TextField), '  Tirage  ');
      await tester.pump();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(results, [const SessionChoiceCreate('Tirage')]);
    });

    testWidgets('the keyboard submits too', (tester) async {
      final results = await open(tester, templates: const []);

      await tester.enterText(find.byType(TextField), 'Tirage');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(results, [const SessionChoiceCreate('Tirage')]);
    });

    testWidgets('a blank name creates nothing', (tester) async {
      final results = await open(tester, templates: const []);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(results, isEmpty);
      expect(find.text('Mercredi'), findsOneWidget);
    });
  });
}
