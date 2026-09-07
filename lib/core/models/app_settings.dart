import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// Display unit for weights. Storage is always kilograms.
enum WeightUnit { kg, lb }

/// Display unit for distances. Storage is always metres.
enum DistanceUnit { km, mi }

/// Which intensity scale the user is shown. Only one appears at a time.
enum IntensityScale { rpe, rir }

/// Theme preference. Dark is the design's default.
enum AppThemeMode { system, light, dark }

/// The single row of user preferences (PRD §5.7).
///
/// Hydrated at startup; M4 gives it a UI. Units are a **display concern
/// only** — nothing here changes what is stored.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required String id,
    @Default(WeightUnit.kg) WeightUnit unitWeight,
    @Default(DistanceUnit.km) DistanceUnit unitDistance,
    @Default(IntensityScale.rpe) IntensityScale intensityScale,
    @Default(120) int defaultRestSeconds,
    @Default(true) bool audioCues,
    @Default(true) bool vibration,
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
  }) = _AppSettings;
}
