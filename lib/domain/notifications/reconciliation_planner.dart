import '../ladder/ladder_tables.dart';
import '../models/date_math.dart';
import '../models/ladder_offset.dart';
import '../models/renewal.dart';
import 'notification_copy.dart';
import 'notification_stage.dart';

/// The pure half of the reconciliation mechanism named in
/// docs/technical/04-scheduling-and-stack.md §2: "recompute, from item +
/// entitlement data, exactly which notifications *should* be pending."
/// This class answers exactly that question — given the current portfolio
/// and "now," which notification occurrences should exist — and nothing
/// more. It never touches a database, a plugin, or the OS notification
/// tray, which is what makes it directly unit testable without a device
/// (the brief's own instruction: "test what can be tested honestly").
///
/// The actual reconciliation *engine* (`ReconciliationService`, in
/// `lib/services/notifications/`) is the untested, unverifiable half — it
/// diffs this planner's output against `scheduled_notifications` rows and
/// calls into `flutter_local_notifications`/`workmanager`, none of which
/// can run in this environment.
///
/// **This is also where REQ-16 (edit/delete rescheduling) and REQ-17.2
/// (clock/timezone jumps) actually get satisfied — as a side effect of
/// being a pure, stateless function of "the current portfolio + now,"
/// not as three separate mechanisms.** Call this again after any edit,
/// delete, or clock change, and the answer is always correct from
/// scratch; there is nothing "remembered" here to get stale.
class ReconciliationPlanner {
  const ReconciliationPlanner._();

  /// The full desired-notification set across every item in [items], as
  /// of [now]. Terminal-`Done` items ([Renewal.isDone] `== true`)
  /// contribute nothing — see the invariant documented on
  /// [RenewalDao.markDone] this depends on: `isDone` is only ever true
  /// for a genuinely terminal outcome, never for a recurring item
  /// mid-cycle, so this check is *not* the bug named in the task brief
  /// ("Done as a scheduling-suppression flag") — it's the correct
  /// terminal case.
  static List<DesiredNotification> planFor({
    required List<Renewal> items,
    required DateTime now,
  }) {
    final today = dateOnly(now);
    final result = <DesiredNotification>[];
    for (final item in items) {
      result.addAll(_planForItem(item: item, today: today));
    }
    return result;
  }

  static List<DesiredNotification> _planForItem({
    required Renewal item,
    required DateTime today,
  }) {
    if (item.isDone) return const [];

    final dueDate = dateOnly(item.dueDate);
    // Matches StatusCalculator's corrected overdue boundary exactly (see
    // that class's fix note) — a due date on or before today is Overdue,
    // not "still upcoming." The planner and the list status must agree
    // on this boundary, or a due-today item could show "Due soon" on the
    // list while receiving an overdue Day-0 nag, or vice versa.
    final overdue = !dueDate.isAfter(today);

    return overdue
        ? _overdueStages(item: item, dueDate: dueDate, today: today)
        : _ladderStages(item: item, dueDate: dueDate, today: today);
  }

  /// REQ-3.1 — pre-due ladder stages. A stage whose date has already
  /// passed relative to [today] is silently skipped, never fired
  /// retroactively (REQ-3.1, REQ-17.1).
  static List<DesiredNotification> _ladderStages({
    required Renewal item,
    required DateTime dueDate,
    required DateTime today,
  }) {
    final offsets = LadderTables.paidLadderStages(item.type, customTier: item.customTier);
    final result = <DesiredNotification>[];

    for (var i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      final stageDate = dateOnly(offset.dateBefore(dueDate));
      if (stageDate.isBefore(today)) continue;

      result.add(_ladderEntry(item: item, dueDate: dueDate, offset: offset, stageDate: stageDate, index: i));
    }
    return result;
  }

  static DesiredNotification _ladderEntry({
    required Renewal item,
    required DateTime dueDate,
    required LadderOffset offset,
    required DateTime stageDate,
    required int index,
  }) {
    return DesiredNotification(
      renewalId: item.id,
      renewalType: item.type,
      itemLabel: item.label,
      kind: NotificationKind.ladderStage,
      stageKey: 'ladder:$index',
      fireOn: stageDate,
      title: NotificationCopy.ladderStageTitle(item.label, offset),
      body: NotificationCopy.ladderStageBody(item.type, dueDate),
      expandedLineText: NotificationCopy.groupLineText(
        itemLabel: item.label,
        isOverdue: false,
        ladderOffset: offset,
      ),
    );
  }

  /// REQ-3.3 — overdue follow-through (paid ladder only; this slice, like
  /// the rest of the codebase, has no free/paid distinction wired in yet
  /// — see `LadderTables`' own class doc). REQ-17.1's one asymmetric
  /// rule: the Day-0 nag always fires "immediately" (clamped forward to
  /// [today]) even if the due date is deeply in the past — every later
  /// stage follows the normal skip-if-already-past rule.
  static List<DesiredNotification> _overdueStages({
    required Renewal item,
    required DateTime dueDate,
    required DateTime today,
  }) {
    final daysAfter = LadderTables.overdueNagDaysAfterDue(item.type, customTier: item.customTier);
    final result = <DesiredNotification>[];

    for (var i = 0; i < daysAfter.length; i++) {
      final offsetDays = daysAfter[i];
      var stageDate = dateOnly(dueDate.add(Duration(days: offsetDays)));

      if (offsetDays == 0) {
        if (stageDate.isBefore(today)) stageDate = today;
      } else if (stageDate.isBefore(today)) {
        continue;
      }

      result.add(DesiredNotification(
        renewalId: item.id,
        renewalType: item.type,
        itemLabel: item.label,
        kind: NotificationKind.overdueNag,
        stageKey: 'overdue:$i',
        fireOn: stageDate,
        title: NotificationCopy.overdueNagTitle(item.label),
        body: NotificationCopy.overdueNagBody(dueDate, stageDate),
        expandedLineText: NotificationCopy.groupLineText(itemLabel: item.label, isOverdue: true),
      ));
    }
    return result;
  }
}
