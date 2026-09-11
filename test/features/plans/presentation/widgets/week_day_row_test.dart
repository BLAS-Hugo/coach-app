import 'package:coach_app/features/plans/presentation/widgets/week_day_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  const accent = Color(0xFFE9A23B);

  group('WeekDayRow', () {
    testWidgets('reads a session day as the day, name and size', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          body: WeekDayRow(
            weekday: DateTime.monday,
            accent: accent,
            editable: true,
            sessionName: 'Haut du corps — poussée',
            sessionMeta: '6 exercices · 24 séries',
          ),
        ),
      );

      expect(find.text('LUN'), findsOneWidget);
      expect(find.text('Haut du corps — poussée'), findsOneWidget);
      expect(find.text('6 exercices · 24 séries'), findsOneWidget);
      expect(find.byKey(WeekDayRow.handleKey(DateTime.monday)), findsOneWidget);
      expect(find.text('repos'), findsNothing);
    });

    testWidgets('reads a rest day as repos with a +', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: WeekDayRow(
            weekday: DateTime.tuesday,
            accent: accent,
            editable: true,
            isLast: true,
          ),
        ),
      );

      expect(find.text('MAR'), findsOneWidget);
      expect(find.text('repos'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(
        // Merged into the row's own node, which the whole row taps for.
        find.bySemanticsLabel(RegExp('Ajouter une séance le mardi')),
        findsOneWidget,
      );
    });

    testWidgets('a session without a size shows its name alone', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          body: WeekDayRow(
            weekday: DateTime.friday,
            accent: accent,
            editable: true,
            sessionName: 'Tirage',
          ),
        ),
      );

      expect(find.text('Tirage'), findsOneWidget);
    });

    testWidgets('a tap opens the day', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Scaffold(
          body: WeekDayRow(
            weekday: DateTime.tuesday,
            accent: accent,
            editable: true,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('repos'));

      expect(taps, 1);
    });

    testWidgets('dragging a session onto another day reports where from', (
      tester,
    ) async {
      final drops = <(int, int)>[];
      await tester.pumpApp(
        Scaffold(
          body: Column(
            children: [
              for (final (weekday, name) in [
                (DateTime.monday, 'Haut'),
                (DateTime.tuesday, null),
                (DateTime.wednesday, 'Bas'),
              ])
                WeekDayRow(
                  weekday: weekday,
                  accent: accent,
                  editable: true,
                  sessionName: name,
                  onSessionDropped: (from) => drops.add((from, weekday)),
                ),
            ],
          ),
        ),
      );

      final handle = find.byKey(WeekDayRow.handleKey(DateTime.monday));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('repos')));
      await tester.pump();
      // The row under the finger lifts to meet the drag.
      await gesture.up();
      await tester.pumpAndSettle();

      expect(drops, [(DateTime.monday, DateTime.tuesday)]);
    });

    testWidgets('a session dropped back on its own day goes nowhere', (
      tester,
    ) async {
      final drops = <int>[];
      await tester.pumpApp(
        Scaffold(
          body: WeekDayRow(
            weekday: DateTime.monday,
            accent: accent,
            editable: true,
            sessionName: 'Haut',
            onSessionDropped: drops.add,
          ),
        ),
      );

      final handle = find.byKey(WeekDayRow.handleKey(DateTime.monday));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(drops, isEmpty);
    });

    testWidgets('a read-only day has no handle, no + and no tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        Scaffold(
          body: Column(
            children: [
              WeekDayRow(
                weekday: DateTime.monday,
                accent: accent,
                editable: false,
                sessionName: 'Haut',
                onTap: () => taps++,
              ),
              WeekDayRow(
                weekday: DateTime.tuesday,
                accent: accent,
                editable: false,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Haut'));
      await tester.tap(find.text('repos'));

      expect(taps, 0);
      expect(find.byKey(WeekDayRow.handleKey(DateTime.monday)), findsNothing);
      expect(find.text('+'), findsNothing);
      expect(find.byType(DragTarget<int>), findsNothing);
    });
  });
}
