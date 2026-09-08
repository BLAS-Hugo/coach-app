import 'package:coach_app/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTheme', () {
    test('registers both token extensions on each theme', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        expect(theme.extension<AppColors>(), isNotNull);
        expect(theme.extension<AppTypography>(), isNotNull);
      }
    });

    test('dark and light carry the handoff brightness and background', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.dark.surfaceBase);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        AppColors.light.surfaceBase,
      );
    });

    testWidgets('context extensions resolve the dark tokens', (tester) async {
      late AppColors colors;
      late AppTypography typography;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            colors = context.colors;
            typography = context.typography;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(colors.surfaceBase, AppColors.dark.surfaceBase);
      expect(typography.dataDisplay.fontSize, 44);
    });

    testWidgets('context extensions resolve the light tokens', (tester) async {
      late AppColors colors;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            colors = context.colors;
            return const SizedBox.shrink();
          },
        ),
        themeMode: ThemeMode.light,
      );

      expect(colors.surfaceBase, AppColors.light.surfaceBase);
    });
  });

  group('AppColors', () {
    test('onAccent inverts between themes', () {
      expect(AppColors.dark.onAccent, const Color(0xFF101215));
      expect(AppColors.light.onAccent, const Color(0xFFFFFFFF));
    });

    test('accentFor picks the accent matching the plan type', () {
      const colors = AppColors.dark;
      expect(colors.accentFor(isStrength: true), colors.accentStrength);
      expect(colors.accentFor(isStrength: false), colors.accentEndurance);
    });

    test('accentWash applies the per-theme opacity to the accent', () {
      const dark = AppColors.dark;
      expect(dark.accentWash(dark.accentStrength).a, closeTo(0.12, 0.001));
      const light = AppColors.light;
      expect(light.accentWash(light.accentEndurance).a, closeTo(0.10, 0.001));
    });

    test(
      'lerp interpolates every token and returns this when other is null',
      () {
        const dark = AppColors.dark;
        const light = AppColors.light;
        expect(dark.lerp(null, 0.5), same(dark));
        expect(dark.lerp(light, 0).surfaceBase, dark.surfaceBase);
        expect(dark.lerp(light, 1).surfaceBase, light.surfaceBase);
        expect(dark.lerp(light, 1).stateDone, light.stateDone);
        expect(dark.lerp(light, 1).accentWashOpacity, closeTo(0.10, 0.001));
      },
    );

    test('copyWith replaces only the given token', () {
      const dark = AppColors.dark;
      final copy = dark.copyWith(textPrimary: const Color(0xFF000000));
      expect(copy.textPrimary, const Color(0xFF000000));
      expect(copy.surfaceBase, dark.surfaceBase);
      // A no-arg copy must fall through to `this` on every token.
      expect(dark.copyWith().textPrimary, dark.textPrimary);
      expect(dark.copyWith().stateMissed, dark.stateMissed);
    });
  });

  group('AppTypography', () {
    test('every data style uses tabular figures and the mono family', () {
      final type = AppTypography.standard(const Color(0xFFFFFFFF));
      for (final style in [
        type.dataDisplay,
        type.dataLarge,
        type.dataBody,
        type.dataSmall,
      ]) {
        expect(style.fontFamily, AppFontFamily.mono);
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('text styles use Archivo and never fall below the 10sp floor', () {
      final type = AppTypography.standard(const Color(0xFFFFFFFF));
      for (final style in [
        type.headingL,
        type.headingM,
        type.body,
        type.label,
        type.labelMicro,
      ]) {
        expect(style.fontFamily, AppFontFamily.archivo);
        expect(style.fontSize, greaterThanOrEqualTo(10));
      }
    });

    test('dataDisplay is 44/48, the largest glyph in the app', () {
      final type = AppTypography.standard(const Color(0xFFFFFFFF));
      expect(type.dataDisplay.fontSize, 44);
      expect(type.dataDisplay.height, closeTo(48 / 44, 0.0001));
    });

    test('label tracking is +0.09em', () {
      final type = AppTypography.standard(const Color(0xFFFFFFFF));
      expect(type.label.letterSpacing, closeTo(11 * 0.09, 0.0001));
      expect(type.labelMicro.letterSpacing, closeTo(10 * 0.09, 0.0001));
    });

    test('copyWith and lerp behave', () {
      final type = AppTypography.standard(const Color(0xFFFFFFFF));
      final other = AppTypography.standard(const Color(0xFF000000));
      expect(type.lerp(null, 0.5), same(type));
      expect(type.lerp(other, 1).body.color, const Color(0xFF000000));
      expect(
        type.copyWith(body: const TextStyle(fontSize: 99)).body.fontSize,
        99,
      );
      expect(type.copyWith().body, type.body);
    });
  });
}
