import 'package:flutter/material.dart';

/// The two families the design allows. Nothing else may be used.
///
/// The `.ttf` files are not vendored yet — see `assets/fonts/README.md`.
/// Until they are, Flutter falls back to the platform default and the
/// weights and metrics below still apply.
abstract final class AppFontFamily {
  /// Headings and running text. Weights 400 / 500 / 600.
  static const String archivo = 'Archivo';

  /// **All** data. Weights 500 / 600, always tabular.
  static const String mono = 'IBMPlexMono';
}

/// Type tokens from the design handoff.
///
/// Every `data*` style carries [FontFeature.tabularFigures] — that is what
/// keeps numeric columns aligned across rows, and it is not optional.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.dataDisplay,
    required this.dataLarge,
    required this.dataBody,
    required this.dataSmall,
    required this.headingL,
    required this.headingM,
    required this.body,
    required this.label,
    required this.labelMicro,
  });

  /// Builds the scale in [color]; the scale itself is theme-independent.
  factory AppTypography.standard(Color color) {
    TextStyle mono(double size, double lineHeight, FontWeight weight) {
      return TextStyle(
        fontFamily: AppFontFamily.mono,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }

    TextStyle archivo(
      double size,
      double lineHeight,
      FontWeight weight, {
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: AppFontFamily.archivo,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
      );
    }

    return AppTypography(
      dataDisplay: mono(44, 48, FontWeight.w600),
      dataLarge: mono(28, 32, FontWeight.w600),
      dataBody: mono(15, 20, FontWeight.w500),
      dataSmall: mono(12, 16, FontWeight.w500),
      headingL: archivo(22, 28, FontWeight.w600),
      headingM: archivo(18, 24, FontWeight.w600),
      body: archivo(15, 22, FontWeight.w400),
      // +0.09em, resolved against the font size.
      label: archivo(11, 14, FontWeight.w600, letterSpacing: 11 * 0.09),
      labelMicro: archivo(10, 13, FontWeight.w600, letterSpacing: 10 * 0.09),
    );
  }

  /// Rest countdown, block elapsed time. The largest glyph in the app is
  /// a digit.
  final TextStyle dataDisplay;

  /// Dominant value of a progress screen.
  final TextStyle dataLarge;

  /// Notation: `4 × 8 @ 60 kg`.
  final TextStyle dataBody;

  /// Date strip, units, rest.
  final TextStyle dataSmall;

  /// Screen title.
  final TextStyle headingL;

  /// Session name.
  final TextStyle headingM;

  /// Running text. Floor of 14sp.
  final TextStyle body;

  /// Section labels and plan types. Uppercase at the call site.
  final TextStyle label;

  /// Restricted scope: caption under a figure in a summary band, stepper
  /// caption, chart axis, badge letter. Nowhere else.
  final TextStyle labelMicro;

  @override
  AppTypography copyWith({
    TextStyle? dataDisplay,
    TextStyle? dataLarge,
    TextStyle? dataBody,
    TextStyle? dataSmall,
    TextStyle? headingL,
    TextStyle? headingM,
    TextStyle? body,
    TextStyle? label,
    TextStyle? labelMicro,
  }) {
    return AppTypography(
      dataDisplay: dataDisplay ?? this.dataDisplay,
      dataLarge: dataLarge ?? this.dataLarge,
      dataBody: dataBody ?? this.dataBody,
      dataSmall: dataSmall ?? this.dataSmall,
      headingL: headingL ?? this.headingL,
      headingM: headingM ?? this.headingM,
      body: body ?? this.body,
      label: label ?? this.label,
      labelMicro: labelMicro ?? this.labelMicro,
    );
  }

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) return this;
    return AppTypography(
      dataDisplay: TextStyle.lerp(dataDisplay, other.dataDisplay, t)!,
      dataLarge: TextStyle.lerp(dataLarge, other.dataLarge, t)!,
      dataBody: TextStyle.lerp(dataBody, other.dataBody, t)!,
      dataSmall: TextStyle.lerp(dataSmall, other.dataSmall, t)!,
      headingL: TextStyle.lerp(headingL, other.headingL, t)!,
      headingM: TextStyle.lerp(headingM, other.headingM, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelMicro: TextStyle.lerp(labelMicro, other.labelMicro, t)!,
    );
  }
}
