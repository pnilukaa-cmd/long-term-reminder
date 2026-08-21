import 'package:flutter/material.dart';

import '../../domain/models/renewal_type.dart';

/// Maps each preset type to a Material icon approximating the mockups'
/// hand-drawn glyph (booklet, shield, ribbon, car, box, heart, star) — not
/// a pixel match, since building bespoke vector icons wasn't worth it for
/// this slice. Flagged in the developer handoff.
IconData iconForType(RenewalType type) {
  switch (type) {
    case RenewalType.passport:
      return Icons.menu_book_outlined;
    case RenewalType.insurance:
      return Icons.shield_outlined;
    case RenewalType.licence:
      return Icons.workspace_premium_outlined;
    case RenewalType.vehicle:
      return Icons.directions_car_outlined;
    case RenewalType.warranty:
      return Icons.inventory_2_outlined;
    case RenewalType.healthCheck:
      return Icons.favorite_outline;
    case RenewalType.custom:
      return Icons.star_outline;
  }
}
