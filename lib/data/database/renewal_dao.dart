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
  /// point). [nextDueDate] is null for non-recurring outcomes (Warranty,
  /// or a "No" answer to Custom's repeat prompt) — the due date is left
  /// untouched in that case, since there's no next cycle.
  Future<void> markDone(
    int id, {
    required DateTime completedAt,
    DateTime? nextDueDate,
  }) {
    return (update(renewalItems)..where((t) => t.id.equals(id))).write(
      RenewalItemsCompanion(
        isDone: const Value(true),
        lastCompletedAt: Value(completedAt),
        dueDate: nextDueDate != null ? Value(nextDueDate) : const Value.absent(),
        updatedAt: Value(completedAt),
      ),
    );
  }
}
