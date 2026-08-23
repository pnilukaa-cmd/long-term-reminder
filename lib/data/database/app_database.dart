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

  /// Bumped from 1 → 2 by this slice: adds `scheduled_notifications`
  /// (`tables.dart`'s doc comment on that table has the full rationale).
  /// No existing column on any table changed shape, so upgrading is
  /// additive-only — see [migration].
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(scheduledNotifications);
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
