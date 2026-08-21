import '../models/custom_tier.dart';
import '../models/ladder_offset.dart';
import '../models/renewal_type.dart';

/// Static ladder data, straight out of
/// docs/design/02-v1-design.md §2 / §2a / §2b and
/// docs/requirements/03-v1-acceptance-criteria.md REQ-3.1/3.2/3.3.
///
/// Entitlement/paywall gating (free vs. paid tier — REQ-3.2, REQ-14) is
/// explicitly out of scope for this slice (no billing plugin exists yet).
/// [paidLadderStages] is used throughout this slice's UI as "the ladder"
/// for every item, since there is no free tier to distinguish from yet.
/// [freeReminderOffset] is still implemented and unit-tested here because
/// it's pure, cheap, and genuinely specified — it's just not wired into any
/// UI gating in this slice. See the developer handoff notes for the
/// explicit call-out.
class LadderTables {
  const LadderTables._();

  /// REQ-3.1 — paid ladder per type, ordered furthest-from-due-date first
  /// (matches the mockups' stage-chip left-to-right ordering).
  static List<LadderOffset> paidLadderStages(
    RenewalType type, {
    CustomTier? customTier,
  }) {
    switch (type) {
      case RenewalType.passport:
        return const [
          LadderOffset(6, OffsetUnit.months),
          LadderOffset(3, OffsetUnit.months),
          LadderOffset(1, OffsetUnit.months),
          LadderOffset(1, OffsetUnit.weeks),
        ];
      case RenewalType.insurance:
        return const [
          LadderOffset(21, OffsetUnit.days),
          LadderOffset(7, OffsetUnit.days),
          LadderOffset(1, OffsetUnit.days),
        ];
      case RenewalType.licence:
        return const [
          LadderOffset(90, OffsetUnit.days),
          LadderOffset(30, OffsetUnit.days),
          LadderOffset(7, OffsetUnit.days),
        ];
      case RenewalType.vehicle:
        return const [
          LadderOffset(30, OffsetUnit.days),
          LadderOffset(14, OffsetUnit.days),
          LadderOffset(3, OffsetUnit.days),
        ];
      case RenewalType.warranty:
        return const [
          LadderOffset(30, OffsetUnit.days),
          LadderOffset(7, OffsetUnit.days),
        ];
      case RenewalType.healthCheck:
        return const [
          LadderOffset(30, OffsetUnit.days),
          LadderOffset(14, OffsetUnit.days),
          LadderOffset(3, OffsetUnit.days),
        ];
      case RenewalType.custom:
        switch (customTier ?? CustomTier.defaultTier) {
          case CustomTier.short:
            return const [
              LadderOffset(7, OffsetUnit.days),
              LadderOffset(3, OffsetUnit.days),
              LadderOffset(1, OffsetUnit.days),
            ];
          case CustomTier.medium:
            return const [
              LadderOffset(30, OffsetUnit.days),
              LadderOffset(7, OffsetUnit.days),
              LadderOffset(1, OffsetUnit.days),
            ];
          case CustomTier.long:
            return const [
              LadderOffset(90, OffsetUnit.days),
              LadderOffset(30, OffsetUnit.days),
              LadderOffset(7, OffsetUnit.days),
            ];
        }
    }
  }

  /// REQ-3.2 — free tier's single, type-tuned reminder. Not wired into any
  /// gating this slice (see class doc) but specified and tested.
  static LadderOffset freeReminderOffset(
    RenewalType type, {
    CustomTier? customTier,
  }) {
    switch (type) {
      case RenewalType.passport:
        return const LadderOffset(3, OffsetUnit.months);
      case RenewalType.insurance:
        return const LadderOffset(7, OffsetUnit.days);
      case RenewalType.licence:
        return const LadderOffset(30, OffsetUnit.days);
      case RenewalType.vehicle:
        return const LadderOffset(14, OffsetUnit.days);
      case RenewalType.warranty:
        return const LadderOffset(30, OffsetUnit.days);
      case RenewalType.healthCheck:
        return const LadderOffset(30, OffsetUnit.days);
      case RenewalType.custom:
        switch (customTier ?? CustomTier.defaultTier) {
          case CustomTier.short:
            return const LadderOffset(3, OffsetUnit.days);
          case CustomTier.medium:
            return const LadderOffset(7, OffsetUnit.days);
          case CustomTier.long:
            return const LadderOffset(30, OffsetUnit.days);
        }
    }
  }

  /// REQ-3.3 — day-offsets after the due date an overdue nag fires on
  /// (paid tier only). Not wired to any actual notification in this slice
  /// (scheduling is next slice's work) but specified and tested since it's
  /// pure, cheap, real domain logic that the next slice will consume
  /// directly.
  static List<int> overdueNagDaysAfterDue(RenewalType type, {CustomTier? customTier}) {
    switch (type) {
      case RenewalType.passport:
        return const [0, 10, 30];
      case RenewalType.insurance:
        return const [0, 3, 10, 30];
      case RenewalType.licence:
        return const [0, 7, 21];
      case RenewalType.vehicle:
        return const [0, 3, 10, 30];
      case RenewalType.warranty:
        return const [0];
      case RenewalType.healthCheck:
        return const [0, 30];
      case RenewalType.custom:
        return const [0, 7, 21];
    }
  }
}
