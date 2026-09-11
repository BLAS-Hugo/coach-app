import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/features/plans/presentation/widgets/template_meta.dart';
import 'package:coach_app/l10n/gen/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsFr();
  const template = SessionTemplate(id: 't1', planId: 'p1', name: 'Haut');

  group('templateMeta', () {
    test('sizes a strength session by exercises and sets', () {
      const summary = SessionTemplateSummary(
        template: template,
        exerciseCount: 6,
        setCount: 24,
      );

      expect(
        templateMeta(l10n, summary, type: PlanType.strength),
        '6 exercices · 24 séries',
      );
    });

    test('uses the singular for one of each', () {
      const summary = SessionTemplateSummary(
        template: template,
        exerciseCount: 1,
        setCount: 1,
      );

      expect(
        templateMeta(l10n, summary, type: PlanType.strength),
        '1 exercice · 1 série',
      );
    });

    test('sizes an endurance session by blocks', () {
      const summary = SessionTemplateSummary(
        template: template,
        enduranceBlockCount: 7,
      );

      expect(templateMeta(l10n, summary, type: PlanType.endurance), '7 blocs');
    });

    test('says so when a session is still empty', () {
      const summary = SessionTemplateSummary(template: template);

      expect(
        templateMeta(l10n, summary, type: PlanType.strength),
        'séance vide',
      );
    });
  });
}
