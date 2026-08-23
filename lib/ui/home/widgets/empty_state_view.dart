import 'package:flutter/material.dart';

import '../../../domain/models/renewal_type.dart';
import '../../../theme/app_dimens.dart';
import '../../common/type_badge.dart';

/// First-run empty state, matching `01-home-list.html` panel p2 — the
/// empty state *is* the first step of the add flow (design doc §1a): all
/// seven type presets as tappable tiles, so cold-launch to first tracked
/// item is one tap. Only shown when there are zero items total, ever
/// (REQ-4.1) — the home screen is responsible for that gating, not this
/// widget.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.onTypeSelected});

  final ValueChanged<RenewalType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp5, AppSpacing.sp4, AppSpacing.sp7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.notifications_outlined, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(height: AppSpacing.sp4),
          const Text(
            'What do you want to track first?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "Pick a type to get started — we'll remind you early enough to actually act, not just in time to panic.",
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.sp5),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sp3,
            mainAxisSpacing: AppSpacing.sp3,
            childAspectRatio: 1.35,
            children: [
              for (final type in RenewalType.values.where((t) => t != RenewalType.custom))
                _TypeTile(type: type, onTap: () => onTypeSelected(type)),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),
          _TypeTile(type: RenewalType.custom, wide: true, onTap: () => onTypeSelected(RenewalType.custom)),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type, required this.onTap, this.wide = false});

  final RenewalType type;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Same dark-elevation fix as RenewalCard (design doc §7a) — a resting
    // tile needs `surfaceContainer` in dark, not `surfaceContainerLowest`
    // (which sits below the scaffold and reads as a recessed hole).
    final tileColor = scheme.brightness == Brightness.dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sp4),
        decoration: BoxDecoration(
          color: tileColor,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppShapes.lg),
        ),
        child: wide
            ? Row(
                children: [
                  TypeBadge(type: type, size: 36),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(
                    child: Text(
                      type.displayName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TypeBadge(type: type, size: 36),
                  const SizedBox(height: AppSpacing.sp2),
                  Text(
                    type.shortName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
