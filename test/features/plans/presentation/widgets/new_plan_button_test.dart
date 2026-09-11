import 'package:coach_app/features/plans/presentation/widgets/new_plan_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('NewPlanButton', () {
    testWidgets('renders the label behind a "+"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(NewPlanButton(onPressed: () {}));

      expect(find.text('+ Nouveau plan'), findsOneWidget);
      // The glyph is decoration; the button announces the plain label.
      expect(
        tester.getSemantics(find.byType(NewPlanButton)),
        isSemantics(isButton: true, label: 'Nouveau plan'),
      );

      // Disposed here rather than in a tearDown: the framework checks for
      // leaked handles before tearDowns run.
      semantics.dispose();
    });

    testWidgets('reports a tap', (tester) async {
      var taps = 0;
      await tester.pumpApp(NewPlanButton(onPressed: () => taps++));

      await tester.tap(find.byType(NewPlanButton));

      expect(taps, 1);
    });

    testWidgets('repaints its outline when the theme changes', (tester) async {
      await tester.pumpApp(NewPlanButton(onPressed: () {}));
      final painter = tester
          .widget<CustomPaint>(find.byKey(NewPlanButton.outlineKey))
          .painter!;

      // The outline is drawn in a theme colour, so a theme swap must reach
      // the canvas rather than reuse the painted layer.
      await tester.pumpApp(
        NewPlanButton(onPressed: () {}),
        themeMode: ThemeMode.light,
      );
      // MaterialApp lerps between themes, so the new colour only lands once
      // that animation has run out.
      await tester.pumpAndSettle();
      final repainted = tester
          .widget<CustomPaint>(find.byKey(NewPlanButton.outlineKey))
          .painter!;

      expect(repainted.shouldRepaint(painter), isTrue);
      expect(repainted.shouldRepaint(repainted), isFalse);
    });
  });
}
