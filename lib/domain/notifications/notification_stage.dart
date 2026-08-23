import '../models/renewal_type.dart';

/// The two kinds of notification this app ever fires, per
/// docs/design/02-v1-design.md §2/§4 and REQ-3.1/REQ-3.3. Snooze is cut
/// from v1 (scope doc §7, "Rejected") — there is no third kind.
enum NotificationKind { ladderStage, overdueNag }

/// The state machine for a `scheduled_notifications` row, per
/// docs/technical/04-scheduling-and-stack.md §2.
///
/// - [pending] — armed with `flutter_local_notifications` (`zonedSchedule`,
///   `AndroidScheduleMode.inexactAllowWhileIdle`); its `fireOn` date is
///   still in the future (or "now," for a Day-0 nag).
/// - [fired] — its `fireOn` date has passed, within a plausible delivery
///   window (inexact scheduling can slip by hours, not days — see the
///   scheduling ADR §1). Terminal: never re-armed, never recreated.
/// - [skipped] — its `fireOn` date passed *without* a plausible delivery
///   window (a clock jump forward, or the device being off/Doze-deferred
///   for an unusually long stretch) — REQ-17.2's explicit rule: skipped
///   over, never burst-fired later. Terminal, same as [fired].
/// - [cancelled] — the desired-notification set no longer includes this
///   occurrence at all (item edited, deleted, or its type/tier changed) —
///   REQ-16.1/16.2. Terminal.
///
/// [fired] vs [skipped] is purely a bookkeeping/observability distinction
/// (surfaced in the debug scheduled-notifications screen) — functionally,
/// both are "done, never touch again." Nothing downstream branches on
/// which of the two a row ended up as.
enum ScheduledNotificationStatus { pending, fired, cancelled, skipped }

/// One concrete "this should be scheduled" occurrence, as computed by
/// [ReconciliationPlanner] — pure domain data, no drift/plugin dependency,
/// so it's trivially unit testable and independent of how it's eventually
/// persisted or handed to `flutter_local_notifications`.
class DesiredNotification {
  const DesiredNotification({
    required this.renewalId,
    required this.renewalType,
    required this.itemLabel,
    required this.kind,
    required this.stageKey,
    required this.fireOn,
    required this.title,
    required this.body,
    required this.expandedLineText,
  });

  final int renewalId;
  final RenewalType renewalType;
  final String itemLabel;
  final NotificationKind kind;

  /// A stable identity for this occurrence, independent of its *date* —
  /// e.g. `"ladder:2"` (the 3rd ladder stage, furthest-first ordering) or
  /// `"overdue:0"` (the Day-0 nag). This is what the reconciliation engine
  /// diffs against previously-persisted `scheduled_notifications` rows for
  /// the same item:
  /// - same [stageKey], same [fireOn] → already correctly scheduled,
  ///   nothing to do.
  /// - same [stageKey], different [fireOn] → the due date (or type, via a
  ///   changed offset table) moved; cancel and reschedule under the
  ///   existing row (REQ-16.1).
  /// - a DB row's [stageKey] isn't in the freshly-computed set at all →
  ///   cancel it outright (item deleted, edited out of overdue, or the
  ///   type changed so this slot no longer exists).
  /// - a [stageKey] in the freshly-computed set has no matching DB row →
  ///   brand new, insert + schedule.
  final String stageKey;

  /// The calendar day (local midnight) this should fire on. Day
  /// granularity only — every acceptance criterion in this project is
  /// written against "fires on [date]," never an hour/minute (REQ-11.2's
  /// resolution, design doc §1).
  final DateTime fireOn;

  final String title;
  final String body;

  /// REQ-12.2's expanded-group per-line text (e.g. `"MOT — Honda Civic ·
  /// 3 days before"` / `"Car insurance · overdue"`) — precomputed here
  /// rather than re-derived by the notification service, so the service
  /// layer never needs its own copy of the domain's stage-label logic.
  final String expandedLineText;

  /// REQ-12.1's grouping key — notifications sharing a calendar day
  /// collapse into one Android grouped/summary notification.
  String get groupDateKey =>
      '${fireOn.year.toString().padLeft(4, '0')}-${fireOn.month.toString().padLeft(2, '0')}-${fireOn.day.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'DesiredNotification(renewalId: $renewalId, stageKey: $stageKey, fireOn: $fireOn, title: "$title")';
}
