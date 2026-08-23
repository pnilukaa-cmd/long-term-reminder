import '../models/custom_tier.dart';
import '../models/ladder_offset.dart';
import '../models/renewal_type.dart';

/// Static ladder data, straight out of
/// docs/design/02-v1-design.md §2 / §2a / §2b and
/// docs/requirements/03-v1-acceptance-criteria.md REQ-3.1/3.2/3.3.
///
/// **Entitlement/paywall gating is wired in as of the billing slice** —
/// [ReconciliationPlanner] (scheduling), `LadderTrackView`/`_LadderCard`
/// (item detail's locked-stage rendering), and `LadderPreviewCard`
/// (Add/Edit's live preview) all choose between [paidLadderStages] and
/// [freeReminderOffset] based on a live entitlement read
/// (`lib/data/repository/entitlement_repository.dart`), per REQ-3.1/3.2.
/// This class itself stays a pure, entitlement-unaware data table — the
/// gating decision is made by every *caller*, not here, matching
/// `LadderTrack`'s own "gate the rendering, not the data" seam.
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
