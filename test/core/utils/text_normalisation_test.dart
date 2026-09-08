import 'package:coach_app/core/utils/text_normalisation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldForSearch', () {
    test('lowercases', () {
      expect(foldForSearch('Squat'), 'squat');
    });

    test('trims and collapses inner whitespace', () {
      expect(foldForSearch('  squat   bulgare '), 'squat bulgare');
    });

    test('strips the diacritics French exercise names carry', () {
      expect(foldForSearch('Élévations latérales'), 'elevations laterales');
      expect(foldForSearch('Soulevé de terre'), 'souleve de terre');
      expect(foldForSearch('Tirage à la poulie'), 'tirage a la poulie');
    });

    test('leaves an already-folded string alone', () {
      expect(foldForSearch('squat'), 'squat');
    });

    test('folds the ligature œ', () {
      expect(foldForSearch('Cœur'), 'coeur');
    });
  });
}
