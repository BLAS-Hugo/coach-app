import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/new_plan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('NewPlanRequest', () {
    const request = NewPlanRequest(name: 'Haut / bas', type: PlanType.strength);

    test('is equal by name and type', () {
      expect(
        request,
        const NewPlanRequest(name: 'Haut / bas', type: PlanType.strength),
      );
      expect(
        request.hashCode,
        const NewPlanRequest(
          name: 'Haut / bas',
          type: PlanType.strength,
        ).hashCode,
      );
    });

    test('differs on either field, and from anything else', () {
      expect(
        request,
        isNot(const NewPlanRequest(name: 'Bas', type: PlanType.strength)),
      );
      expect(
        request,
        isNot(
          const NewPlanRequest(name: 'Haut / bas', type: PlanType.endurance),
        ),
      );
      expect(request, isNot('Haut / bas'));
    });
  });

  group('NewPlanSheet', () {
    /// Pumps a screen whose only button opens the sheet, and hands back what
    /// the sheet resolved to once it closes.
    Future<NewPlanRequest?> openSheet(WidgetTester tester) async {
      NewPlanRequest? result;

      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opens on the strength type, with creation held back', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openSheet(tester);

      expect(find.text('Nouveau plan'), findsOneWidget);
      expect(find.text('FORCE'), findsOneWidget);
      expect(find.text('ENDURANCE'), findsOneWidget);

      expect(
        tester.getSemantics(find.text('FORCE')),
        isSemantics(isSelected: true, isButton: true, label: 'Force'),
      );
      expect(
        tester.getSemantics(find.text('ENDURANCE')),
        isSemantics(isSelected: false),
      );

      // Disposed here rather than in a tearDown: the framework checks for
      // leaked handles before tearDowns run.
      semantics.dispose();
    });

    testWidgets('will not create a plan with no name', (tester) async {
      NewPlanRequest? result;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      // Still open, nothing produced.
      expect(find.text('Nouveau plan'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('ignores a name that is only whitespace', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      // Submitting from the keyboard bypasses the disabled button, so the
      // guard has to live in the handler too.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Nouveau plan'), findsOneWidget);
    });

    testWidgets('returns a trimmed name and the chosen type', (tester) async {
      NewPlanRequest? result;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Semi-marathon  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENDURANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(
        result,
        const NewPlanRequest(name: 'Semi-marathon', type: PlanType.endurance),
      );
    });

    testWidgets('submits from the keyboard', (tester) async {
      NewPlanRequest? result;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Haut / bas');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        result,
        const NewPlanRequest(name: 'Haut / bas', type: PlanType.strength),
      );
    });

    testWidgets('resolves to nothing when cancelled', (tester) async {
      NewPlanRequest? result;
      var closed = false;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await NewPlanSheet.show(context);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Haut / bas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('switches back to the strength type', (tester) async {
      NewPlanRequest? result;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await NewPlanSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Haut / bas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENDURANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FORCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(result?.type, PlanType.strength);
    });
  });
}
