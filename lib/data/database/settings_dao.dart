import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

/// Health check note dismissal key (REQ-1.2) — a per-install flag, not
/// per-item or per-session. More keys can be added here as later slices
/// need small persisted flags; this stays a plain key/value store rather
/// than growing bespoke columns.
const String kHealthCheckNoteDismissedKey = 'health_check_note_dismissed';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
  }

  Future<bool> isHealthCheckNoteDismissed() async {
    final value = await getValue(kHealthCheckNoteDismissedKey);
    return value == 'true';
  }

  Future<void> setHealthCheckNoteDismissed() => setValue(kHealthCheckNoteDismissedKey, 'true');
}
