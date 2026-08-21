/// Shape and spacing scale from docs/design/02-v1-design.md §7. Kept as
/// plain constants (rather than folded into ThemeData) since Flutter's
/// theming system doesn't have a first-class "named shape scale" the way
/// it does color roles — widgets reference these directly.
class AppShapes {
  const AppShapes._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;
}

/// 4dp grid, per design doc §7.
class AppSpacing {
  const AppSpacing._();

  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 24;
  static const double sp6 = 32;
  static const double sp7 = 48;
}
