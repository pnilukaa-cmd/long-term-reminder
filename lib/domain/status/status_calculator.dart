import '../ladder/ladder_calculator.dart';
import '../models/custom_tier.dart';
import '../models/date_math.dart';
import '../models/renewal_status.dart';
import '../models/renewal_type.dart';

/// Computes an item's [RenewalStatus] per REQ-4.2. Pure and independent of
/// the UI/database layers so it's directly unit testable.
class StatusCalculator {
  const StatusCalculator._();

  /// - `isDone` always wins → [RenewalStatus.done].
  /// - Otherwise, a due date in the past → [RenewalStatus.overdue].
  /// - Otherwise, once the ladder's closest-to-due stage has fired →
  ///   [RenewalStatus.dueSoon] (REQ-4.2's BA default: "due soon" starts
  ///   once the final pre-due stage has fired, not from a separate
  ///   hand-picked threshold).
  /// - Otherwise → [RenewalStatus.upcoming].
  static RenewalStatus computeStatus({
    required RenewalType type,
    required DateTime dueDate,
    required bool isDone,
    required DateTime now,
    CustomTier? customTier,
  }) {
    if (isDone) return RenewalStatus.done;

    if (daysBetween(now, dueDate) < 0) return RenewalStatus.overdue;

    final stages = LadderCalculator.paidLadderInstances(
      type: type,
      dueDate: dueDate,
      now: now,
      customTier: customTier,
    );
    final closest = LadderCalculator.closestToDueStage(stages);
    if (closest != null && closest.fired) return RenewalStatus.dueSoon;

    return RenewalStatus.upcoming;
  }
}
