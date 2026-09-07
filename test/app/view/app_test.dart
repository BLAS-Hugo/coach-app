import 'package:coach_app/app/app.dart';
import 'package:coach_app/features/calendar/presentation/view/day_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App', () {
    testWidgets('renders the day view through the router', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);
    });

    testWidgets('applies the dark theme tokens by default', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(DayViewPage));
      expect(context.colors.surfaceBase, AppColors.dark.surfaceBase);
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });
}
