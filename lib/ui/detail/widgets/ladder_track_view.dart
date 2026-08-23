import 'package:flutter/material.dart';

import '../../../domain/format/relative_date.dart';
import '../../../domain/ladder/ladder_track.dart';
import '../../../theme/app_dimens.dart';

/// The horizontal ladder-track timeline, matching `.track` across
/// `docs/design/mockups/03-item-detail.html`'s success-state panels — the
/// app's core differentiator, surfaced at the moment it matters most (design
/// doc §3).
///
/// Renders every entry unlocked (see [LadderTrack]'s class doc on the
/// paywall-gating seam) — there is deliberately no `.t-dot.locked`
/// treatment here yet.
class LadderTrackView extends StatelessWidget {
  const LadderTrackView({super.key, required this.entries});

  final List<LadderTrackEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp2),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // The connecting horizontal line behind every dot, matching
          // `.track::before`.
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(height: 2, color: Theme.of(context).colorScheme.outlineVariant),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final entry in entries) Expanded(child: _TrackItem(entry: entry))],
          ),
        ],
      ),
    );
  }
}

class _TrackItem extends StatelessWidget {
  const _TrackItem({required this.entry});

  final LadderTrackEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (entry.kind) {
      case LadderTrackEntryKind.today:
        // `.t-dot.today` — a small solid dark dot, no icon.
        return Column(
          children: [
            const SizedBox(height: 7),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: scheme.onSurface, shape: BoxShape.circle),
            ),
            const SizedBox(height: 5),
            Text(
              'Today',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ],
        );

      case LadderTrackEntryKind.due:
        return _Dot(
          background: scheme.errorContainer,
          border: scheme.error,
          iconColor: scheme.onErrorContainer,
          icon: Icons.outlined_flag,
          label: entry.label,
          date: entry.date,
        );

      case LadderTrackEntryKind.stage:
        if (entry.fired) {
          return _Dot(
            background: scheme.primary,
            border: scheme.primary,
            iconColor: scheme.onPrimary,
            icon: Icons.check,
            label: entry.label,
            date: entry.date,
          );
        }
        if (entry.isNext) {
          return _Dot(
            background: scheme.primaryContainer,
            border: scheme.primary,
            iconColor: scheme.onPrimaryContainer,
            icon: Icons.schedule_outlined,
            label: entry.label,
            date: entry.date,
          );
        }
        return _Dot(
          background: scheme.surfaceContainerLowest,
          border: scheme.outlineVariant,
          iconColor: scheme.outline,
          icon: Icons.schedule_outlined,
          label: entry.label,
          date: entry.date,
        );
    }
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.date,
  });

  final Color background;
  final Color border;
  final Color iconColor;
  final IconData icon;
  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: Border.all(color: border, width: 2)),
          alignment: Alignment.center,
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
        Text(
          RelativeDateFormatter.shortDate(date),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
