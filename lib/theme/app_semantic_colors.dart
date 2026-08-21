import 'package:flutter/material.dart';

import '../domain/models/renewal_type.dart';
import 'category_tint.dart';

/// The two semantic roles design doc §7 defines beyond stock Material 3
/// (which only ships `error`, not `warning`/`success`), plus the seven
/// category tints. Modelled as a [ThemeExtension] — the idiomatic Flutter
/// way to add custom, theme-aware, light/dark-lerpable roles that
/// `ColorScheme` itself doesn't have room for.
///
/// Used for "Due soon" (warning) and "Done" (success) status treatment
/// (REQ-4.2, design doc §6's status-language table) and for each type's
/// icon badge (design doc §6's category-tint table).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.categoryTints,
  });

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Map<RenewalType, CategoryTint> categoryTints;

  CategoryTint tintFor(RenewalType type) => categoryTints[type]!;

  /// Values taken verbatim from the mockups' `:root` block.
  static const light = AppSemanticColors(
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFDEA6),
    onWarningContainer: Color(0xFF2A1800),
    success: Color(0xFF146C2E),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFB6F2C4),
    onSuccessContainer: Color(0xFF002109),
    categoryTints: kCategoryTintsLight,
  );

  /// No dark mockup exists — these values are my own M3-style dark-tonal
  /// derivation from the light role's hue, not a designer-specified
  /// palette. Flagged explicitly in the developer handoff.
  static const dark = AppSemanticColors(
    warning: Color(0xFFFFB951),
    onWarning: Color(0xFF452B00),
    warningContainer: Color(0xFF633F00),
    onWarningContainer: Color(0xFFFFDEA6),
    success: Color(0xFF7DDB92),
    onSuccess: Color(0xFF00390F),
    successContainer: Color(0xFF00531B),
    onSuccessContainer: Color(0xFFB6F2C4),
    categoryTints: kCategoryTintsDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Map<RenewalType, CategoryTint>? categoryTints,
  }) {
    return AppSemanticColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      categoryTints: categoryTints ?? this.categoryTints,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    final tints = <RenewalType, CategoryTint>{};
    for (final type in RenewalType.values) {
      tints[type] = CategoryTint.lerp(categoryTints[type]!, other.categoryTints[type]!, t);
    }
    return AppSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      categoryTints: tints,
    );
  }
}

/// Convenience accessor: `context.semanticColors.warning`, etc.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors => Theme.of(this).extension<AppSemanticColors>()!;
}
