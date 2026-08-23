import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'renewal_dao.g.dart';

/// Data access for renewal items. Kept deliberately thin — recurrence math,
/// ladder math, and status computation all live in `lib/domain/`, pure and
/// database-independent; this class is just reads/writes.
@DriftAccessor(tables: [RenewalItems])
class RenewalDao extends DatabaseAccessor<AppDatabase> with _$RenewalDaoMixin {
  RenewalDao(super.db);

  /// Live query — the list screen's success/loading/error states are all
  /// driven off this stream (a `StreamBuilder`'s connection-state covers
  /// loading, `hasError` covers the error state, empty data covers the
  /// empty state).
  Stream<List<RenewalItem>> watchAllItems() => select(renewalItems).watch();

  Future<RenewalItem?> getItemById(int id) => (select(renewalItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Live single-row query — item detail's loading/error("not found")/
  /// success states (REQ-5.1) are all driven off this stream directly,
  /// the same way the list screen is driven off [watchAllItems]: a `null`
  /// emission (row deleted, e.g. via another flow while this screen is
  /// open) is exactly REQ-5.1's "item not found" case, with no separate
  /// polling or manual re-fetch needed.
  Stream<RenewalItem?> watchItemById(int id) =>
      (select(renewalItems)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Every item, once — as opposed to [watchAllItems]'s live stream. Used
  /// by the reconciliation pass (which needs a single current snapshot per
  /// run, not a subscription) and by the "is this the user's very first
  /// item" check that gates the Android 13+ notification-permission prompt
  /// (per the task brief: primed after the first item is added, not on
  /// first launch).
  Future<List<RenewalItem>> getAllItemsOnce() => select(renewalItems).get();

  /// Cheap at this app's realistic scale (a personal renewal tracker; not
  /// thousands of rows) — a plain row count via drift's `count()`
  /// aggregate rather than materializing every row just to measure it.
  Future<int> countAll() async {
    final countExp = renewalItems.id.count();
    final query = selectOnly(renewalItems)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> insertItem(RenewalItemsCompanion entry) => into(renewalItems).insert(entry);

  /// Full-row replace, used by edit (REQ-16.1) — the caller is responsible
  /// for supplying every column that should survive, since `replace`
  /// overwrites the whole row.
  Future<bool> updateItem(RenewalItemsCompanion entry) => update(renewalItems).replace(entry);

  Future<int> deleteItemById(int id) => (delete(renewalItems)..where((t) => t.id.equals(id))).go();

  /// Commits a mark-done action (REQ-9, REQ-10.2's "window lapses" commit
  /// point). [nextDueDate] is null for non-recurring/terminal outcomes
  /// (Warranty, or a "No" answer to Custom's repeat prompt) — the due date
  /// is left untouched in that case, since there's no next cycle.
  ///
  /// **This is the fix for the bug named in the product-manager revision
  /// note of 2026-08-21 (scope doc §3d): `Done` describes a completed
  /// *cycle*, not the item.** Previously this method set `isDone: true`
  /// unconditionally, which parked every recurring item in the collapsed
  /// `Done` section forever, regardless of whether a next due date had
  /// just been set — silently suppressing that item's entire next-cycle
  /// ladder, since [status_calculator.dart]'s `isDone` check short-circuits
  /// before ever looking at the due date, and (once notification
  /// scheduling exists) [ReconciliationPlanner] treats a terminal `Done`
  /// item as having nothing left to schedule.
  ///
  /// The corrected rule, straight from §3d: `isDone` is true **iff**
  /// [nextDueDate] is null (a genuinely terminal outcome) — the moment a
  /// next due date is set, the item is an ordinary item with a future due
  /// date again, and must recompute its status/schedule normally, exactly
  /// like any other item. [ReconciliationPlanner] depends on this
  /// invariant holding — see its class doc.
  ///
  /// **Also implements the snapshot half of `Undo last completion`**
  /// (scope doc §3d, developer task brief item 2): before writing the new
  /// state, this reads the row's *current* `dueDate`/`lastCompletedAt`
  /// and persists them as `preCompletionDueDate`/
  /// `preCompletionLastCompletedAt`, and sets `hasUndoableCompletion:
  /// true` — exactly the prior state [undoLastCompletion] needs to
  /// restore. This naturally enforces the single-level-undo boundary
  /// without a separate invalidation step: a *second* mark-done on the
  /// same item simply overwrites the snapshot with whatever was current
  /// immediately before *that* commit, so only the most recent event is
  /// ever recoverable.
  ///
  /// Also clears `pendingRecurrenceDecision` unconditionally — whether
  /// this commit is the deferred decision from a notification-triggered
  /// mark-done finally being resolved on item detail, or an entirely
  /// ordinary in-app mark-done, either way the item is no longer awaiting
  /// anything once this write lands.
  Future<void> markDone(
    int id, {
    required DateTime completedAt,
    DateTime? nextDueDate,
  }) async {
    final current = await getItemById(id);
    if (current == null) return; // deleted out from under this call — nothing to do
    final isTerminal = nextDueDate == null;
    await (update(renewalItems)..where((t) => t.id.equals(id))).write(
      RenewalItemsCompanion(
        isDone: Value(isTerminal),
        lastCompletedAt: Value(completedAt),
        dueDate: nextDueDate != null ? Value(nextDueDate) : const Value.absent(),
        updatedAt: Value(completedAt),
        pendingRecurrenceDecision: const Value(false),
        hasUndoableCompletion: const Value(true),
        preCompletionDueDate: Value(current.dueDate),
        preCompletionLastCompletedAt: Value(current.lastCompletedAt),
      ),
    );
  }

  /// Sets [RenewalItems.pendingRecurrenceDecision] — the notification-
  /// triggered `Mark done` path (REQ-9.5), once its remaining pending
  /// notification rows have already been cancelled by the caller. Leaves
  /// `dueDate`/`isDone`/`lastCompletedAt` untouched, since no recurrence
  /// decision has actually been made yet — there's nothing for `Undo last
  /// completion` to revert until the deferred banner on item detail
  /// resolves this via the ordinary [markDone] path above.
  Future<void> markPendingRecurrenceDecision(int id) =>
      (update(renewalItems)..where((t) => t.id.equals(id))).write(
        RenewalItemsCompanion(pendingRecurrenceDecision: const Value(true), updatedAt: Value(DateTime.now())),
      );

  /// `Undo last completion` (scope doc §3d) — reverts the most recent
  /// [markDone] commit by restoring the snapshot it took. Returns `false`
  /// (a no-op) if the row is gone or [RenewalItems.hasUndoableCompletion]
  /// is already false — the single-level-undo boundary: invalidated by
  /// any subsequent edit ([RenewalRepository.updateItem] clears the flag
  /// explicitly), another mark-done (overwrites the snapshot before this
  /// could ever run), a delete (row gone), or a prior use of this same
  /// action (flag already cleared below).
  Future<bool> undoLastCompletion(int id) async {
    final current = await getItemById(id);
    if (current == null || !current.hasUndoableCompletion) return false;
    await (update(renewalItems)..where((t) => t.id.equals(id))).write(
      RenewalItemsCompanion(
        isDone: const Value(false),
        dueDate: Value(current.preCompletionDueDate ?? current.dueDate),
        lastCompletedAt: Value(current.preCompletionLastCompletedAt),
        hasUndoableCompletion: const Value(false),
        preCompletionDueDate: const Value(null),
        preCompletionLastCompletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return true;
  }
}
