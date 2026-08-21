import 'package:flutter/material.dart';

import '../../../domain/models/renewal_type.dart';
import '../../../theme/app_dimens.dart';
import '../../common/type_badge.dart';

/// The horizontally-scrollable type-chip row at the top of Add/Edit,
/// matching `.type-row`/`.type-chip` in `02-add-edit-item.html`.
class TypeSelector extends StatelessWidget {
  const TypeSelector({super.key, required this.selected, required this.onChanged});

  final RenewalType? selected;
  final ValueChanged<RenewalType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RenewalType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = RenewalType.values[index];
          final isSelected = type == selected;
          return _TypeChip(type: type, isSelected: isSelected, onTap: () => onChanged(type));
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.isSelected, required this.onTap});

  final RenewalType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.md),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppShapes.md),
                border: isSelected ? Border.all(color: scheme.primary, width: 2.5) : null,
              ),
              padding: const EdgeInsets.all(2),
              child: TypeBadge(type: type, size: 44),
            ),
            const SizedBox(height: 4),
            Text(
              type.shortName,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
