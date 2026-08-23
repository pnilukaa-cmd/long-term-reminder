import '../../data/database/notification_dao.dart';
import '../../data/repository/renewal_repository.dart';
import 'notification_service.dart';
import 'reconciliation_service.dart';

/// Handles REQ-9.5's `Mark done` notification action — the one place both
/// the live-process callback (`NotificationService.init`'s
/// `onMarkDoneWhileAlive`) and the killed-process background isolate
/// (`notification_background_handler.dart`) converge, so the behaviour is
/// identical regardless of which callback fired it.
class NotificationActionHandler {
  const NotificationActionHandler._();

  static Future<void> handleMarkDone({
    required int renewalId,
    required RenewalRepository renewalRepository,
    required NotificationDao notificationDao,
    required NotificationService notificationService,
    required ReconciliationService reconciliationService,
  }) async {
    final item = await renewalRepository.getById(renewalId);
    if (item == null) return; // already deleted — nothing to do

    if (!item.type.hasRecurrencePrompt) {
      // Warranty only (REQ-9.3) — the one type where "no next cycle" is
      // always the correct, complete answer, so a notification tap can
      // fully resolve it without any UI. Matches the in-app quick-done
      // flow's own Warranty branch exactly.
      await renewalRepository.commitMarkDone(renewalId, nextDueDate: null);
    } else {
      // REQ-9.5's other branch: every other type needs a real recurrence
      // decision ("when's the next one due?") that this app only knows how
      // to ask through UI. Design doc §4 defers that question to an inline
      // banner on item detail — not a second notification — the next time
      // the app is opened.
      //
      // **Resolved, not still a gap**: item detail now exists
      // (`lib/ui/detail/item_detail_screen.dart`) and renders exactly that
      // deferred banner when `pendingRecurrenceDecision` is true, reusing
      // the same recurrence-sheet flow and the same [RenewalRepository
      // .commitMarkDone] commit path every other mark-done goes through —
      // see that screen's `_DeferredRecurrenceBanner`. What this handler
      // does at notification-tap time is unchanged and still correct on
      // its own terms: cancel every still-pending notification for this
      // item's current cycle immediately (so a user who's told the app,
      // via the notification, that they've handled this doesn't keep
      // getting nagged), then mark the item as awaiting its recurrence
      // decision rather than flipping `isDone`/`dueDate` here — this app
      // still has no foreground UI surface at the moment a notification
      // action fires (this handler runs identically whether the process
      // is alive or was launched fresh into a background isolate — see
      // `notification_background_handler.dart`), so the actual "when's it
      // next due?" question genuinely cannot be asked from here. That is
      // the deliberate, stated reason this path still can't complete the
      // recurrence *itself* — it hands off to the one place that can.
      //
      // `markPendingRecurrenceDecision` is also what stops the
      // `reconciliationService.reconcile()` call at the end of this method
      // from immediately re-arming the very notifications just cancelled
      // above — see [ReconciliationPlanner]'s matching check. Without it,
      // this cancel-then-reconcile sequence would silently undo itself in
      // the same call.
      final rows = await notificationDao.getRowsForRenewal(renewalId);
      for (final row in rows) {
        if (row.status != 'pending') continue;
        await notificationService.cancel(row.id);
        await notificationDao.setStatus(row.id, 'cancelled');
      }
      await renewalRepository.markPendingRecurrenceDecision(renewalId);
    }

    // Re-run reconciliation so DB/OS state converges immediately rather
    // than waiting for the next launch/periodic pass — matters most for
    // the Warranty branch above, where `isDone` just flipped true and
    // every remaining scheduled row for this item needs cancelling now.
    await reconciliationService.reconcile();
  }
}
