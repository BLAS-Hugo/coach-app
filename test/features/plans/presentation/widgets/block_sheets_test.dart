import 'package:coach_app/core/utils/date_only.dart';
import 'package:coach_app/features/plans/presentation/widgets/block_duration_sheet.dart';
import 'package:coach_app/features/plans/presentation/widgets/new_block_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  /// Pumps a button opening a sheet through [show], and collects what the
  /// sheet resolves to.
  Future<List<T?>> open<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext context) show,
  ) async {
    final results = <T?>[];
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await show(context)),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('BlockDurationSheet', () {
    testWidgets('starts on the current length and hands back the new one', (
      tester,
    ) async {
      final results = await open(
        tester,
        (context) => BlockDurationSheet.show(context, initialWeeks: 5),
      );

      expect(find.text('Durée du bloc'), findsOneWidget);
      expect(find.text('5 semaines'), findsOneWidget);
      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(results, [6]);
    });

    testWidgets('never opens below its minimum', (tester) async {
      final results = await open(
        tester,
        (context) => BlockDurationSheet.show(context, initialWeeks: 2, min: 3),
      );

      expect(find.text('3 semaines'), findsOneWidget);
      await tester.tap(find.text('−'));
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(results, [3]);
    });
  });

  group('NewBlockSheet', () {
    final today = DateOnly(2026, 9, 7);

    Future<List<NewBlockRequest?>> openBlock(WidgetTester tester) => open(
      tester,
      (context) =>
          NewBlockSheet.show(context, today: today, defaultName: 'Bloc 1'),
    );

    test('requests compare by value', () {
      NewBlockRequest request() =>
          NewBlockRequest(name: 'Bloc 1', startDate: today, durationWeeks: 4);

      expect(request(), request());
      expect(request().hashCode, request().hashCode);
      expect(
        request(),
        isNot(
          NewBlockRequest(name: 'Bloc 2', startDate: today, durationWeeks: 4),
        ),
      );
    });

    testWidgets('defaults to its name, today and four weeks', (tester) async {
      final results = await openBlock(tester);

      expect(find.text('Nouveau bloc'), findsOneWidget);
      expect(find.text('lundi 7 septembre 2026'), findsOneWidget);
      expect(find.text('4 semaines'), findsOneWidget);
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(results, [
        NewBlockRequest(name: 'Bloc 1', startDate: today, durationWeeks: 4),
      ]);
    });

    testWidgets('takes a name, a start date and a length', (tester) async {
      final results = await openBlock(tester);

      await tester.enterText(find.byType(TextField), 'Accumulation');
      await tester.tap(find.text('lundi 7 septembre 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('14'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(results, [
        NewBlockRequest(
          name: 'Accumulation',
          startDate: DateOnly(2026, 9, 14),
          durationWeeks: 5,
        ),
      ]);
    });

    testWidgets('a dismissed date picker keeps the date', (tester) async {
      await openBlock(tester);

      await tester.tap(find.text('lundi 7 septembre 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();

      expect(find.text('lundi 7 septembre 2026'), findsOneWidget);
    });

    testWidgets('a blank name creates nothing', (tester) async {
      final results = await openBlock(tester);

      await tester.enterText(find.byType(TextField), '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(results, isEmpty);
    });

    testWidgets('the keyboard submits too', (tester) async {
      final results = await openBlock(tester);

      await tester.enterText(find.byType(TextField), 'Bloc A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(results.single?.name, 'Bloc A');
    });
  });
}
