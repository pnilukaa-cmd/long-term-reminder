import 'package:flutter/material.dart';

import '../../../domain/ladder/ladder_tables.dart';
import '../../../domain/models/custom_tier.dart';
import '../../../domain/models/renewal_type.dart';
import '../../../theme/app_dimens.dart';

/// REQ-2.5's Short/Medium/Long segmented control for the Custom type.
class CustomTierSelector extends StatelessWidget {
  const CustomTierSelector({super.key, required this.selected, required this.onChanged});

  final CustomTier selected;
  final ValueChanged<CustomTier> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppShapes.full),
          ),
          child: Row(
            children: [
              for (final tier in CustomTier.values)
                Expanded(
                  child: _Segment(
                    label: tier.displayName,
                    active: tier == selected,
                    onTap: () => onChanged(tier),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _caption(),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _caption() {
    final stages = LadderTables.paidLadderStages(RenewalType.custom, customTier: selected);
    final offsets = stages.map((s) => '${s.value}').join('/');
    return 'Medium is the default — 30/7/1 days before, unchanged from today. '
        'Short = 7/3/1, Long = 90/30/7. Currently: $offsets days before.';
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.full),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppShapes.full),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
