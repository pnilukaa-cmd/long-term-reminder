import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart';
import '../../data/database/notification_dao.dart';
import '../../data/repository/entitlement_repository.dart';
import '../../data/repository/renewal_repository.dart';
import '../../domain/models/date_math.dart';
import '../../domain/notifications/notification_diff.dart';
import '../../domain/notifications/notification_stage.dart';
import '../../domain/notifications/reconciliation_planner.dart';
import 'notification_ids.dart';
import 'notification_service.dart';

/// The impure half of the reconciliation mechanism named in
/// docs/technical/04-scheduling-and-stack.md §2 — the actual "source of
/// correctness," run on every app launch/foreground and via the
/// `workmanager` periodic task (task brief items 1–2). Ties together:
/// [ReconciliationPlanner] (what *should* be scheduled, pure),
/// [NotificationDiffEngine] (what to do about it, pure), [NotificationDao]
/// (the DB half of the source of truth), and [NotificationService] (the
/// actual OS/plugin calls). None of this is unit-testable without a
/// database and a plugin, which is exactly why the two pure halves above
/// exist and are tested independently.
class ReconciliationService {
  ReconciliationService({
    required RenewalRepository renewalRepository,
    required NotificationDao notificationDao,
    required NotificationService notificationService,
    required EntitlementRepository entitlementRepository,
  })  : _renewalRepository = renewalRepository,
        _notificationDao = notificationDao,
        _notificationService = notificationService,
        _entitlementRepository = entitlementRepository;

  final RenewalRepository _renewalRepository;
  final NotificationDao _notificationDao;
  final NotificationService _notificationService;

  /// The single global entitlement flag this whole reconciliation pass is
  /// gated on (developer task brief §2 — "this is where the paywall
  /// becomes real"). Read fresh on every [reconcile] call rather than
  /// cached, so a purchase, a restore, or (REQ-17.3) a loss of
  /// entitlement is picked up the moment the next reconciliation pass
  /// runs — the same "recompute from scratch every time, trust nothing
  /// remembered" principle [ReconciliationPlanner]'s own class doc already
  /// states for edits/deletes/clock changes.
  final EntitlementRepository _entitlementRepository;

  Future<void> reconcile({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final today = dateOnly(effectiveNow);

    final items = await _renewalRepository.getAllOnce();
    final isEntitled = await _entitlementRepository.isEntitled();
    final desired = ReconciliationPlanner.planFor(items: items, now: effectiveNow, isEntitled: isEntitled);
    final existingRows = await _notificationDao.getAllRows();

    // Every id still present in the portfolio, terminal-`Done` items
    // excluded — the exact set [ReconciliationPlanner] could still produce
    // entries for (see its class doc on the §3d invariant).
    final activeRenewalIds = items.where((i) => !i.isDone).map((i) => i.id).toSet();

    final existingForDiff = existingRows
        .map(
          (r) => ExistingScheduledRow(
            id: r.id,
            renewalId: r.renewalId,
            stageKey: r.stageKey,
            fireOn: r.fireOn,
            status: r.status,
            groupDateKey: r.groupDateKey,
          ),
        )
        .toList(growable: false);

    final actions = NotificationDiffEngine.diff(
      desired: desired,
      existingRows: existingForDiff,
      activeRenewalIds: activeRenewalIds,
      today: today,
    );

    for (final action in actions) {
      await _apply(action, effectiveNow);
    }

    // REQ-12.1/12.2 — recomputed after the individual-occurrence actions
    // above (which is what determines "pending" going forward), using the
    // set of group keys either currently desired or previously known, so a
    // group that just dropped below 2 items gets its summary cancelled,
    // not just silently orphaned.
    await _reconcileGroupSummaries(desired: desired, previousRows: existingRows);

    // REQ-16.2 — hard-delete `scheduled_notifications` rows for renewals
    // that no longer exist at all (genuinely deleted, not just terminal
    // `Done`) — see NotificationDao.deleteForRenewal's doc comment on why
    // this is explicit rather than a drift FK cascade. Any still-armed OS
    // notification for those rows was already cancelled above (the diff
    // treats a missing/inactive renewal id as [DiffActionKind.cancel]).
    final currentRenewalIds = items.map((i) => i.id).toSet();
    final orphanedRenewalIds = existingRows.map((r) => r.renewalId).toSet().difference(currentRenewalIds);
    for (final id in orphanedRenewalIds) {
      await _notificationDao.deleteForRenewal(id);
    }
  }

  Future<void> _apply(NotificationDiffAction action, DateTime now) async {
    switch (action.kind) {
      case DiffActionKind.insertAndArm:
        final desired = action.desired!;
        final id = await _notificationDao.insertRow(
          ScheduledNotificationsCompanion.insert(
            renewalId: desired.renewalId,
            kind: desired.kind.name,
            stageKey: desired.stageKey,
            fireOn: desired.fireOn,
            groupDateKey: desired.groupDateKey,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _notificationService.armDesiredNotification(id: id, desired: desired);

      case DiffActionKind.rearm:
        await _notificationService.armDesiredNotification(id: action.existingRowId!, desired: action.desired!);

      case DiffActionKind.rescheduleAndArm:
        final desired = action.desired!;
        await _notificationDao.updateRow(
          action.existingRowId!,
          ScheduledNotificationsCompanion(
            fireOn: Value(desired.fireOn),
            groupDateKey: Value(desired.groupDateKey),
            status: const Value('pending'),
            updatedAt: Value(now),
          ),
        );
        await _notificationService.armDesiredNotification(id: action.existingRowId!, desired: desired);

      case DiffActionKind.markFired:
        await _notificationDao.setStatus(action.existingRowId!, 'fired');
        await _notificationService.cancel(action.existingRowId!);

      case DiffActionKind.markSkipped:
        await _notificationDao.setStatus(action.existingRowId!, 'skipped');
        await _notificationService.cancel(action.existingRowId!);

      case DiffActionKind.cancel:
        await _notificationDao.setStatus(action.existingRowId!, 'cancelled');
        await _notificationService.cancel(action.existingRowId!);
    }
  }

  Future<void> _reconcileGroupSummaries({
    required List<DesiredNotification> desired,
    required List<ScheduledNotification> previousRows,
  }) async {
    final distinctRenewalIdsByGroup = <String, Set<int>>{};
    final labelsByGroup = <String, Set<String>>{};
    for (final d in desired) {
      distinctRenewalIdsByGroup.putIfAbsent(d.groupDateKey, () => <int>{}).add(d.renewalId);
      labelsByGroup.putIfAbsent(d.groupDateKey, () => <String>{}).add(d.itemLabel);
    }

    // Bounded to calendar days this app has actually cared about (currently
    // desired, or previously persisted) — not literally every possible
    // date — so this stays cheap at this app's realistic scale.
    final candidateGroupKeys = <String>{
      ...distinctRenewalIdsByGroup.keys,
      ...previousRows.map((r) => r.groupDateKey),
    };

    for (final groupKey in candidateGroupKeys) {
      final summaryId = NotificationIds.summaryIdFor(groupKey);
      final distinctRenewalIds = distinctRenewalIdsByGroup[groupKey] ?? const <int>{};
      if (distinctRenewalIds.length >= 2) {
        await _notificationService.postGroupSummary(
          summaryId: summaryId,
          groupDateKey: groupKey,
          itemLabels: labelsByGroup[groupKey]!.toList(growable: false),
        );
      } else {
        await _notificationService.cancel(summaryId);
      }
    }
  }
}
