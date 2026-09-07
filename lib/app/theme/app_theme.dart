import 'package:coach_app/app/theme/app_colors.dart';
import 'package:coach_app/app/theme/app_metrics.dart';
import 'package:coach_app/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Builds the two `ThemeData`s from the design tokens.
///
/// The tokens live in [AppColors] and [AppTypography] and are reached from
/// widgets through the `context.colors` / `context.typography` extensions
/// below. The Material `ColorScheme` is filled in so framework widgets do
/// not fall back to purple, but app widgets read the tokens, not the scheme.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final typography = AppTypography.standard(colors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.surfaceBase,
      // No shadow in dark; only floating surfaces are elevated in light.
      shadowColor: brightness == Brightness.dark
          ? const Color(0x00000000)
          : const Color(0x14141A17),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accentStrength,
        onPrimary: colors.onAccent,
        secondary: colors.accentEndurance,
        onSecondary: colors.onAccent,
        surface: colors.surfaceBase,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceRaised,
        surfaceContainerLowest: colors.surfaceSunken,
        outline: colors.borderStrong,
        outlineVariant: colors.borderSubtle,
        error: colors.accentStrength,
        onError: colors.onAccent,
      ),
      textTheme: TextTheme(
        displayLarge: typography.dataDisplay,
        headlineLarge: typography.headingL,
        headlineMedium: typography.headingM,
        bodyLarge: typography.body,
        bodyMedium: typography.body,
        labelLarge: typography.label,
        labelSmall: typography.labelMicro,
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceBase,
        surfaceTintColor: const Color(0x00000000),
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: typography.headingL,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: const Color(0x00000000),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[colors, typography],
    );
  }
}

extension AppThemeX on BuildContext {
  /// Colour tokens for the active theme.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// Type tokens for the active theme.
  AppTypography get typography => Theme.of(this).extension<AppTypography>()!;
}
