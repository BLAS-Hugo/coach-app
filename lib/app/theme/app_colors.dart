import 'package:flutter/material.dart';

/// Role-named colour tokens from the design handoff.
///
/// Nothing in a widget may hardcode a colour: every colour reaches the UI
/// through this extension, read via `Theme.of(context).extension<AppColors>()`
/// or the `context.colors` shorthand in `theme.dart`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentStrength,
    required this.accentEndurance,
    required this.onAccent,
    required this.accentWashOpacity,
    required this.statePlanned,
    required this.stateActive,
    required this.stateDone,
    required this.stateSkipped,
    required this.stateMissed,
  });

  /// Dark is the default theme of the app.
  static const AppColors dark = AppColors(
    surfaceBase: Color(0xFF16181C),
    surfaceRaised: Color(0xFF1E2126),
    surfaceSunken: Color(0xFF101215),
    borderSubtle: Color(0xFF2A2E35),
    borderStrong: Color(0xFF3D434C),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFFA2A9B4),
    textMuted: Color(0xFF6E7681),
    accentStrength: Color(0xFFE9A23B),
    accentEndurance: Color(0xFF58B6E8),
    onAccent: Color(0xFF101215),
    accentWashOpacity: 0.12,
    statePlanned: Color(0xFF3D434C),
    stateActive: Color(0xFFF2F4F7),
    stateDone: Color(0xFF86A98C),
    stateSkipped: Color(0xFF5C636D),
    stateMissed: Color(0xFF454B54),
  );

  static const AppColors light = AppColors(
    surfaceBase: Color(0xFFEDEFF2),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE2E5E9),
    borderSubtle: Color(0xFFD3D8DE),
    borderStrong: Color(0xFFA9B1BA),
    textPrimary: Color(0xFF14171A),
    textSecondary: Color(0xFF4E555E),
    textMuted: Color(0xFF767E88),
    accentStrength: Color(0xFF9C5600),
    accentEndurance: Color(0xFF10658F),
    onAccent: Color(0xFFFFFFFF),
    accentWashOpacity: 0.10,
    statePlanned: Color(0xFFA9B1BA),
    stateActive: Color(0xFF14171A),
    stateDone: Color(0xFF3F6B48),
    stateSkipped: Color(0xFF8A9299),
    stateMissed: Color(0xFFB3B9C0),
  );

  /// Scaffold background. Cold charcoal in dark, never pure black.
  final Color surfaceBase;

  /// Tappable or floating container that must stand out.
  final Color surfaceRaised;

  /// Tracks, rails, fields, action-bar and tab-bar backgrounds.
  final Color surfaceSunken;

  /// Separators and resting card outlines.
  final Color borderSubtle;

  /// Outline of a selected or actionable element.
  final Color borderStrong;

  /// Titles, figures, values.
  final Color textPrimary;

  /// Metadata, units, secondary labels.
  final Color textSecondary;

  /// Uppercase labels and past items. Floor of 10sp, `labelMicro` only.
  final Color textMuted;

  final Color accentStrength;
  final Color accentEndurance;

  /// Text or glyph sitting on a filled accent. Inverts between themes.
  final Color onAccent;

  /// Opacity applied to an accent to build a type-chip background.
  /// Computed rather than stored — see [accentWash].
  final double accentWashOpacity;

  /// `prévue` — outline, never a fill.
  final Color statePlanned;

  /// `en cours` — the only filled container surface in the app.
  final Color stateActive;

  /// `terminée` — always paired with a `✓` glyph.
  final Color stateDone;

  /// `ignorée` — a half-filled track. An explicit user choice.
  final Color stateSkipped;

  /// `manquée` — dotted, no fill, and never red.
  final Color stateMissed;

  /// Background of a plan-type chip: the accent at [accentWashOpacity].
  Color accentWash(Color accent) => accent.withValues(alpha: accentWashOpacity);

  /// The accent for [isStrength], so widgets branch on the plan type once.
  Color accentFor({required bool isStrength}) =>
      isStrength ? accentStrength : accentEndurance;

  @override
  AppColors copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentStrength,
    Color? accentEndurance,
    Color? onAccent,
    double? accentWashOpacity,
    Color? statePlanned,
    Color? stateActive,
    Color? stateDone,
    Color? stateSkipped,
    Color? stateMissed,
  }) {
    return AppColors(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentStrength: accentStrength ?? this.accentStrength,
      accentEndurance: accentEndurance ?? this.accentEndurance,
      onAccent: onAccent ?? this.onAccent,
      accentWashOpacity: accentWashOpacity ?? this.accentWashOpacity,
      statePlanned: statePlanned ?? this.statePlanned,
      stateActive: stateActive ?? this.stateActive,
      stateDone: stateDone ?? this.stateDone,
      stateSkipped: stateSkipped ?? this.stateSkipped,
      stateMissed: stateMissed ?? this.stateMissed,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentStrength: Color.lerp(accentStrength, other.accentStrength, t)!,
      accentEndurance: Color.lerp(accentEndurance, other.accentEndurance, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentWashOpacity:
          accentWashOpacity + (other.accentWashOpacity - accentWashOpacity) * t,
      statePlanned: Color.lerp(statePlanned, other.statePlanned, t)!,
      stateActive: Color.lerp(stateActive, other.stateActive, t)!,
      stateDone: Color.lerp(stateDone, other.stateDone, t)!,
      stateSkipped: Color.lerp(stateSkipped, other.stateSkipped, t)!,
      stateMissed: Color.lerp(stateMissed, other.stateMissed, t)!,
    );
  }
}
