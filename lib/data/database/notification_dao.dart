import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'notification_dao.g.dart';

/// Data access for `scheduled_notifications` — the reliability model's
/// source of truth, per docs/technical/04-scheduling-and-stack.md §2. Kept
/// as thin as [RenewalDao]: `lib/services/notifications/` (specifically
/// `ReconciliationService`) owns every diffing/scheduling decision; this
/// class is just reads/writes.
@DriftAccessor(tables: [ScheduledNotifications])
class NotificationDao extends DatabaseAccessor<AppDatabase> with _$NotificationDaoMixin {
  NotificationDao(super.db);

  /// Every row this app has ever recorded, any status — the raw input to
  /// both the reconciliation diff and the debug scheduled-state screen
  /// (developer task item 7).
  Future<List<ScheduledNotification>> getAllRows() => select(scheduledNotifications).get();

  Future<List<ScheduledNotification>> getRowsForRenewal(int renewalId) =>
      (select(scheduledNotifications)..where((t) => t.renewalId.equals(renewalId))).get();

  Future<int> insertRow(ScheduledNotificationsCompanion entry) => into(scheduledNotifications).insert(entry);

  /// A scoped, partial `.write()` by [id] — deliberately **not**
  /// `.replace()`, whose absent-field behaviour `RenewalDao.updateItem`'s
  /// own doc comment already flags as something not to lean on implicitly.
  /// [patch] only needs to carry the columns actually changing (typically
  /// `fireOn`/`groupDateKey`/`status`/`updatedAt` for a
  /// [DiffActionKind.rescheduleAndArm]) — every other column, including
  /// `createdAt`, is left untouched.
  Future<void> updateRow(int id, ScheduledNotificationsCompanion patch) =>
      (update(scheduledNotifications)..where((t) => t.id.equals(id))).write(patch);

  /// Bookkeeping-only status flip (fired/skipped/cancelled) — never touches
  /// `fireOn`/`groupDateKey`, since those describe what was *desired*, not
  /// what happened to it afterwards.
  Future<void> setStatus(int id, String status) =>
      (update(scheduledNotifications)..where((t) => t.id.equals(id))).write(
        ScheduledNotificationsCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
      );

  /// REQ-16.2 — an item's rows are cleaned up explicitly here (not via a
  /// drift FK cascade — see the table's own doc comment for why) once its
  /// underlying renewal is actually deleted (the undo window has lapsed).
  /// Callers are responsible for cancelling any still-armed OS notification
  /// for each row *before* calling this (see `ReconciliationService`) —
  /// this method only ever touches the database.
  Future<void> deleteForRenewal(int renewalId) =>
      (delete(scheduledNotifications)..where((t) => t.renewalId.equals(renewalId))).go();
}
