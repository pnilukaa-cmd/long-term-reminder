import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'notification_dao.dart';
import 'renewal_dao.dart';
import 'settings_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's single local database — drift over sqlite3, per
/// docs/technical/04-scheduling-and-stack.md §4. Everything lives on-device
/// (REQ-15.2); nothing here ever makes a network call.
@DriftDatabase(
  tables: [RenewalItems, AppSettings, ScheduledNotifications],
  daos: [RenewalDao, SettingsDao, NotificationDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Exposed for tests — pass an in-memory `NativeDatabase.memory()`
  /// executor so unit/widget tests don't touch the real filesystem.
  AppDatabase.forTesting(super.executor);

  /// Bumped from 1 → 2 by the notification-scheduling slice (adds
  /// `scheduled_notifications`) and from 2 → 3 by this slice: adds four
  /// columns to `renewal_items` — `pending_recurrence_decision`,
  /// `has_undoable_completion`, `pre_completion_due_date`,
  /// `pre_completion_last_completed_at` (`tables.dart`'s doc comments on
  /// those columns have the full rationale — the deferred
  /// recurrence-decision banner and `Undo last completion`). No existing
  /// column on any table changed shape, so both upgrades are
  /// additive-only — see [migration].
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(scheduledNotifications);
          }
          if (from < 3) {
            await m.addColumn(renewalItems, renewalItems.pendingRecurrenceDecision);
            await m.addColumn(renewalItems, renewalItems.hasUndoableCompletion);
            await m.addColumn(renewalItems, renewalItems.preCompletionDueDate);
            await m.addColumn(renewalItems, renewalItems.preCompletionLastCompletedAt);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'renewal_reminder.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
