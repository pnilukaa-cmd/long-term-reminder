import 'notification_stage.dart';

/// What to do with one previously-persisted `scheduled_notifications` row or
/// one freshly-desired occurrence, as decided by [NotificationDiffEngine].
/// Pure output — the impure executor (`ReconciliationService`, in
/// `lib/services/notifications/`) is the only thing that turns this into a
/// drift write or a `flutter_local_notifications` call.
enum DiffActionKind {
  /// No DB row exists yet for this desired occurrence — insert one and arm
  /// it.
  insertAndArm,

  /// A `pending` row already exists with the same `stageKey` and the same
  /// `fireOn` — re-arm it anyway (idempotent `zonedSchedule` call). This is
  /// the actual self-heal mechanism named in the scheduling ADR §2: rather
  /// than trying to ask the OS "is this alarm still registered" (which
  /// `flutter_local_notifications` has no direct API for), every
  /// reconciliation pass just re-arms every currently-desired pending
  /// occurrence unconditionally. Cheap, idempotent, and correct regardless
  /// of whether the OS silently lost the alarm (reboot before the boot
  /// receiver ran, an app update, a force-stop the user has since undone
  /// by reopening the app).
  rearm,

  /// A row exists for this `stageKey` (any status) but its `fireOn` no
  /// longer matches the freshly-computed date (a due-date/type edit,
  /// REQ-16.1) — or the row was previously terminal (fired/skipped/
  /// cancelled) and this `stageKey` has legitimately come back into the
  /// desired set (e.g. a due date edited past a stage, then edited back).
  /// Either way: update the row to `pending` with the new `fireOn`, then
  /// arm it.
  rescheduleAndArm,

  /// A `pending` row's `stageKey` dropped out of the desired set purely
  /// because its date passed within a plausible delivery window (REQ-17.2's
  /// normal case, not a clock jump) — mark it `fired`, the terminal,
  /// never-touched-again bookkeeping state.
  markFired,

  /// A `pending` row's `stageKey` dropped out of the desired set and the
  /// gap between its `fireOn` and "today" is too large to be plausible
  /// delivery slippage — REQ-17.2's clock-jump-forward case. Marked
  /// `skipped`, not re-armed, not burst-fired.
  markSkipped,

  /// A `pending` row's `stageKey` dropped out of the desired set because
  /// its renewal was deleted, or is no longer active (terminal `Done`,
  /// REQ-16.2/§3d) — cancel outright.
  cancel,
}

class NotificationDiffAction {
  const NotificationDiffAction({
    required this.kind,
    this.desired,
    this.existingRowId,
    this.existingFireOn,
  });

  final DiffActionKind kind;

  /// Set for [DiffActionKind.insertAndArm], [DiffActionKind.rearm], and
  /// [DiffActionKind.rescheduleAndArm].
  final DesiredNotification? desired;

  /// Set for every kind except [DiffActionKind.insertAndArm] (which has no
  /// existing row yet).
  final int? existingRowId;

  final DateTime? existingFireOn;

  @override
  String toString() => 'NotificationDiffAction($kind, rowId: $existingRowId, desired: $desired)';
}

/// A row from `scheduled_notifications`, expressed without any drift
/// dependency so this stays in `lib/domain/` and is unit-testable without a
/// database. `ReconciliationService` maps drift's generated row class onto
/// this before calling [NotificationDiffEngine.diff].
class ExistingScheduledRow {
  const ExistingScheduledRow({
    required this.id,
    required this.renewalId,
    required this.stageKey,
    required this.fireOn,
    required this.status,
    required this.groupDateKey,
  });

  final int id;
  final int renewalId;
  final String stageKey;
  final DateTime fireOn;

  /// [ScheduledNotificationStatus.name] — kept as a plain string here
  /// (rather than importing that enum) so this class has zero dependency
  /// beyond Dart core; `ReconciliationService` is responsible for the
  /// string↔enum mapping either direction.
  final String status;

  final String groupDateKey;
}

/// The pure half of the reconciliation mechanism, alongside
/// [ReconciliationPlanner] — diffs a freshly-computed desired-notification
/// set against previously-persisted DB rows and decides what should happen
/// to each, per the stageKey-based contract documented on
/// [DesiredNotification.stageKey]. No drift, no plugin, no clock reads
/// beyond the [today] passed in — directly unit testable.
class NotificationDiffEngine {
  const NotificationDiffEngine._();

  /// [activeRenewalIds] — every renewal id currently present in the
  /// portfolio and not terminal-`Done` (i.e. every id [ReconciliationPlanner]
  /// could still produce entries for). Used to tell "this stage's window
  /// simply closed with time" (mark fired/skipped) apart from "this item no
  /// longer exists, or is now terminal" (cancel) for rows whose `stageKey`
  /// dropped out of the desired set.
  static List<NotificationDiffAction> diff({
    required List<DesiredNotification> desired,
    required List<ExistingScheduledRow> existingRows,
    required Set<int> activeRenewalIds,
    required DateTime today,
  }) {
    final actions = <NotificationDiffAction>[];
    final existingByKey = <String, ExistingScheduledRow>{
      for (final row in existingRows) _key(row.renewalId, row.stageKey): row,
    };
    final desiredKeys = <String>{};

    for (final d in desired) {
      final key = _key(d.renewalId, d.stageKey);
      desiredKeys.add(key);
      final existing = existingByKey[key];

      if (existing == null) {
        actions.add(NotificationDiffAction(kind: DiffActionKind.insertAndArm, desired: d));
      } else if (existing.status != 'pending') {
        actions.add(
          NotificationDiffAction(kind: DiffActionKind.rescheduleAndArm, desired: d, existingRowId: existing.id),
        );
      } else if (_sameCalendarDay(existing.fireOn, d.fireOn)) {
        actions.add(NotificationDiffAction(kind: DiffActionKind.rearm, desired: d, existingRowId: existing.id));
      } else {
        actions.add(
          NotificationDiffAction(kind: DiffActionKind.rescheduleAndArm, desired: d, existingRowId: existing.id),
        );
      }
    }

    for (final row in existingRows) {
      if (row.status != 'pending') continue;
      if (desiredKeys.contains(_key(row.renewalId, row.stageKey))) continue;

      if (!activeRenewalIds.contains(row.renewalId)) {
        actions.add(
          NotificationDiffAction(kind: DiffActionKind.cancel, existingRowId: row.id, existingFireOn: row.fireOn),
        );
        continue;
      }

      // Item is still active; this stage's window closed purely with time.
      // A 2-day buffer absorbs ordinary inexact-delivery slippage
      // ("hours, not days" per the scheduling ADR §1) without
      // misclassifying a real clock jump as a normal firing.
      final gapDays = today.difference(row.fireOn).inDays;
      final kind = gapDays <= 2 ? DiffActionKind.markFired : DiffActionKind.markSkipped;
      actions.add(NotificationDiffAction(kind: kind, existingRowId: row.id, existingFireOn: row.fireOn));
    }

    return actions;
  }

  static String _key(int renewalId, String stageKey) => '$renewalId:$stageKey';

  static bool _sameCalendarDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
