import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'renewal_dao.dart';
import 'settings_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's single local database — drift over sqlite3, per
/// docs/technical/04-scheduling-and-stack.md §4. Everything lives on-device
/// (REQ-15.2); nothing here ever makes a network call.
@DriftDatabase(tables: [RenewalItems, AppSettings], daos: [RenewalDao, SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Exposed for tests — pass an in-memory `NativeDatabase.memory()`
  /// executor so unit/widget tests don't touch the real filesystem.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'renewal_reminder.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
