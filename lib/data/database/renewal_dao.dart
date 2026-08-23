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
  Future<void> markDone(
    int id, {
    required DateTime completedAt,
    DateTime? nextDueDate,
  }) {
    final isTerminal = nextDueDate == null;
    return (update(renewalItems)..where((t) => t.id.equals(id))).write(
      RenewalItemsCompanion(
        isDone: Value(isTerminal),
        lastCompletedAt: Value(completedAt),
        dueDate: nextDueDate != null ? Value(nextDueDate) : const Value.absent(),
        updatedAt: Value(completedAt),
      ),
    );
  }
}
