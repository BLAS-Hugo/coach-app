import 'package:coach_app/features/plans/presentation/widgets/sheet_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('WeeksStepper', () {
    Future<List<int>> pumpStepper(
      WidgetTester tester, {
      required int value,
      int min = 1,
      int max = 52,
    }) async {
      final changes = <int>[];
      await tester.pumpApp(
        Scaffold(
          body: WeeksStepper(
            value: value,
            min: min,
            max: max,
            onChanged: changes.add,
          ),
        ),
      );
      return changes;
    }

    testWidgets('reads the value in weeks', (tester) async {
      await pumpStepper(tester, value: 5);

      expect(find.text('5 semaines'), findsOneWidget);
    });

    testWidgets('steps down and up by one', (tester) async {
      final changes = await pumpStepper(tester, value: 5);

      await tester.tap(find.text('−'));
      await tester.tap(find.text('+'));

      expect(changes, [4, 6]);
    });

    testWidgets('stops at its bounds', (tester) async {
      final changes = await pumpStepper(tester, value: 3, min: 3, max: 3);

      await tester.tap(find.text('−'));
      await tester.tap(find.text('+'));

      expect(changes, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Moins')),
        isSemantics(isButton: true, hasEnabledState: true),
      );
    });
  });

  group('SheetActions', () {
    testWidgets('cancel pops without a value', (tester) async {
      Object? result = 'untouched';
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showPlanSheet<int>(
              context,
              SheetFrame(
                title: 'Titre',
                children: [SheetActions(submitLabel: 'OK', onSubmit: () {})],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Titre'), findsNothing);
    });
  });
}
