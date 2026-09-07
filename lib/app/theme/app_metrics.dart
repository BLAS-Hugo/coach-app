/// Spacing scale. No free values — every gap and pad comes from here.
///
/// Density varies by surface: home 24–48 (calm), editor and history 12–16
/// (intermediate), session detail and runner 4–12 (dense).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii. `lg` cards, `md` buttons and fields, `sm` chips and tracks.
abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 999;

  /// Modal sheet, top corners only.
  static const double sheet = 16;
}

/// Touch target heights.
abstract final class AppTouchTarget {
  /// Absolute floor for anything tappable.
  static const double min = 48;

  /// Primary button of a screen.
  static const double primary = 56;

  /// Primary action of the runner, read at arm's length.
  static const double runnerPrimary = 64;
}
