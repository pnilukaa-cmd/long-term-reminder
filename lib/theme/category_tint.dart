import 'package:flutter/material.dart';

import '../domain/models/renewal_type.dart';

/// A container/on-container color pair for one renewal type's icon badge,
/// per docs/design/02-v1-design.md §6's category-tint table. Deliberately
/// a separate color space from status colors (upcoming/due soon/overdue/
/// done) — see the design doc's reasoning: sharing a hue family between
/// "which type" and "how urgent" would be ambiguous at a glance.
@immutable
class CategoryTint {
  const CategoryTint({required this.container, required this.onContainer});

  final Color container;
  final Color onContainer;

  static CategoryTint lerp(CategoryTint a, CategoryTint b, double t) {
    return CategoryTint(
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
    );
  }
}

/// Light-mode category tints, values taken verbatim from the mockups'
/// `:root` custom-property block (identical across all seven mockup
/// files).
const Map<RenewalType, CategoryTint> kCategoryTintsLight = {
  RenewalType.passport: CategoryTint(container: Color(0xFFD3E4FF), onContainer: Color(0xFF001C3B)),
  RenewalType.insurance: CategoryTint(container: Color(0xFFB8EAE3), onContainer: Color(0xFF00201C)),
  RenewalType.licence: CategoryTint(container: Color(0xFFEDDCFF), onContainer: Color(0xFF26005E)),
  RenewalType.vehicle: CategoryTint(container: Color(0xFFF0D9C8), onContainer: Color(0xFF2B1500)),
  RenewalType.warranty: CategoryTint(container: Color(0xFFDDE3F5), onContainer: Color(0xFF131C2E)),
  RenewalType.healthCheck: CategoryTint(container: Color(0xFFF6D9E6), onContainer: Color(0xFF4A1030)),
  RenewalType.custom: CategoryTint(container: Color(0xFFE5E1EC), onContainer: Color(0xFF201B29)),
};

/// Dark-mode category tints. No dark mockup exists (the design doc's own
/// mockups are light-only) — these are my own derivation, roughly
/// inverting each pair's tonal relationship (a darker, more saturated
/// container; a light on-container) while preserving hue, following
/// standard M3 dark-scheme tonal conventions. Flagged in the developer
/// handoff as unverified against any drawn dark design.
const Map<RenewalType, CategoryTint> kCategoryTintsDark = {
  RenewalType.passport: CategoryTint(container: Color(0xFF223A5E), onContainer: Color(0xFFD3E4FF)),
  RenewalType.insurance: CategoryTint(container: Color(0xFF1D3B36), onContainer: Color(0xFFB8EAE3)),
  RenewalType.licence: CategoryTint(container: Color(0xFF3C2E57), onContainer: Color(0xFFEDDCFF)),
  RenewalType.vehicle: CategoryTint(container: Color(0xFF463526), onContainer: Color(0xFFF0D9C8)),
  RenewalType.warranty: CategoryTint(container: Color(0xFF2C3348), onContainer: Color(0xFFDDE3F5)),
  RenewalType.healthCheck: CategoryTint(container: Color(0xFF4A2A38), onContainer: Color(0xFFF6D9E6)),
  RenewalType.custom: CategoryTint(container: Color(0xFF39353F), onContainer: Color(0xFFE5E1EC)),
};
