import 'package:flutter/material.dart';

import '../../domain/models/renewal_type.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_semantic_colors.dart';
import 'type_icons.dart';

/// The rounded, tinted icon badge used on list cards, the type-selection
/// row, and the empty-state tiles — matches `.type-badge` across the
/// mockups.
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.size = 40});

  final RenewalType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = context.semanticColors.tintFor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.container,
        borderRadius: BorderRadius.circular(AppShapes.md),
      ),
      alignment: Alignment.center,
      child: Icon(iconForType(type), color: tint.onContainer, size: size * 0.5),
    );
  }
}
