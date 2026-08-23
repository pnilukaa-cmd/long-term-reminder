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
  /// - Otherwise, a due date on or before today → [RenewalStatus.overdue]
  ///   (REQ-4.2's explicit "due today counts as Overdue, not Due soon"
  ///   day-granularity rule — see the fix note below).
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

    // Bug fix (found while building this slice's notification
    // reconciliation, which needs this exact same overdue boundary to
    // agree with the list's status — see ReconciliationPlanner): this was
    // `daysBetween(now, dueDate) < 0`, which is strictly negative only
    // once the due date is at least one full day in the past. A due date
    // that lands on "today" produces `daysBetween == 0`, which failed
    // that check and fell through to the ladder-closest-stage branch
    // instead — silently contradicting this project's own test for this
    // exact rule ("due today counts as Overdue, not Due soon"). `<= 0`
    // is what that rule actually requires.
    if (daysBetween(now, dueDate) <= 0) return RenewalStatus.overdue;

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
