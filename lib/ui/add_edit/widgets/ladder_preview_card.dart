import 'package:flutter/material.dart';

import '../../../domain/ladder/ladder_tables.dart';
import '../../../domain/models/custom_tier.dart';
import '../../../domain/models/renewal_type.dart';
import '../../../theme/app_dimens.dart';

/// The live-updating ladder preview card, matching `.ladder-preview`
/// across the mockups — REQ-2.3.
class LadderPreviewCard extends StatelessWidget {
  const LadderPreviewCard({super.key, required this.type, this.customTier});

  final RenewalType type;
  final CustomTier? customTier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stages = LadderTables.paidLadderStages(type, customTier: customTier);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sp5),
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 15, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                'Reminders scheduled',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _description(stages.length),
            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer.withValues(alpha: .85), height: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final stage in stages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(AppShapes.full),
                  ),
                  child: Text(
                    stage.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Six of seven types' explanatory copy isn't independently
  /// BA-finalized yet (acceptance criteria §15 explicitly defers this as
  /// a copy-completion pass, not a design decision) — this generates a
  /// reasonable, pattern-consistent line per type rather than leaving the
  /// card blank. Treat as a draft, not final copy.
  String _description(int stageCount) {
    final times = stageCount == 1 ? 'once' : '$stageCount times';
    switch (type) {
      case RenewalType.warranty:
        return "You'll be reminded $times before the due date. No follow-up after — "
            "once a warranty lapses there's nothing left to nag about.";
      case RenewalType.healthCheck:
        return "You'll be reminded $times before the due date. If it passes unmarked, one lighter "
            "check-in follows 30 days later — checkups don't need the daily-risk cadence a lapsed "
            "legal document does.";
      case RenewalType.custom:
        return "Updates live as you change the selector above. You'll be reminded $times before the "
            "due date, then checked on twice more if it passes without being marked done.";
      default:
        return "You'll be reminded $times before the due date, then checked on if it passes without "
            "being marked done.";
    }
  }
}
