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

/// Dark-mode category tints, per design doc §7a (`08-dark-theme.html` §5),
/// replacing the developer's earlier rough tonal-inversion guess. Every
/// value below was hue/chroma-anchored to the light role in CIELAB, then
/// retoned to M3's standard dark container/on-container tonal targets —
/// not a naive lightness inversion. Two deliberate deviations worth
/// knowing about if this table is ever touched again:
/// - **Vehicle**'s chroma is intentionally reined in (1.6× rather than the
///   ~3.1× the other six categories got, with hue nudged 65°→59°) to keep
///   it clay/brown rather than drifting into the corrected dark `warning`
///   role's amber territory — the same "not amber" constraint that chose
///   terracotta for it in light in the first place.
/// - **Health check**'s hue is rotated to 335° in dark (not a literal
///   retone of light's 348°) specifically to keep separation from dark
///   `errorContainer` — verified via Machado et al. protanopia/deuteranopia
///   simulation, not just hue-angle math. See design doc §7a for the full
///   colorblind-verification writeup.
const Map<RenewalType, CategoryTint> kCategoryTintsDark = {
  RenewalType.passport: CategoryTint(container: Color(0xFF004C90), onContainer: Color(0xFFD2E4FF)),
  RenewalType.insurance: CategoryTint(container: Color(0xFF00584E), onContainer: Color(0xFFB8EDE5)),
  RenewalType.licence: CategoryTint(container: Color(0xFF563290), onContainer: Color(0xFFEDDCFF)),
  RenewalType.vehicle: CategoryTint(container: Color(0xFF5E402D), onContainer: Color(0xFFF8DDCD)),
  RenewalType.warranty: CategoryTint(container: Color(0xFF294774), onContainer: Color(0xFFDCE2F5)),
  RenewalType.healthCheck: CategoryTint(container: Color(0xFF6F2F61), onContainer: Color(0xFFFAD9F0)),
  RenewalType.custom: CategoryTint(container: Color(0xFF4B425E), onContainer: Color(0xFFE5E1EC)),
};
