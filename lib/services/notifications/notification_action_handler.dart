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
      // the app is opened. **Item detail is out of scope for this slice**
      // (see the developer task brief's explicit exclusions), so that
      // deferred-decision banner does not exist yet.
      //
      // What this method still does, matching REQ-9.5's other, buildable
      // half exactly ("remaining scheduled stages for that item are
      // cancelled immediately"): every still-pending notification for this
      // item's current cycle is cancelled now, so a user who has already
      // told the app (via the notification) that they've handled this
      // doesn't keep getting nagged about it. `isDone`/`dueDate` are
      // deliberately left untouched — flipping either without a real
      // next-cycle decision would violate scope doc §3d's "Done is
      // per-cycle, not per-item" rule (it would either wrongly park a
      // recurring item in the terminal Done section, or silently invent a
      // next due date nobody chose).
      //
      // **Named gap, not a silent drop**: until item detail's deferred
      // banner exists, a recurring item marked done from a notification
      // keeps showing its current (likely Overdue/Due soon) status on the
      // list, and the user still needs to open the app and use the
      // existing in-app Mark done flow to actually advance the cycle. See
      // the developer handoff.
      final rows = await notificationDao.getRowsForRenewal(renewalId);
      for (final row in rows) {
        if (row.status != 'pending') continue;
        await notificationService.cancel(row.id);
        await notificationDao.setStatus(row.id, 'cancelled');
      }
    }

    // Re-run reconciliation so DB/OS state converges immediately rather
    // than waiting for the next launch/periodic pass — matters most for
    // the Warranty branch above, where `isDone` just flipped true and
    // every remaining scheduled row for this item needs cancelling now.
    await reconciliationService.reconcile();
  }
}
