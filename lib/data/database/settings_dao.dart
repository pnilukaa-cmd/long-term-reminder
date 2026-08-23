import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

/// Health check note dismissal key (REQ-1.2) — a per-install flag, not
/// per-item or per-session. More keys can be added here as later slices
/// need small persisted flags; this stays a plain key/value store rather
/// than growing bespoke columns.
const String kHealthCheckNoteDismissedKey = 'health_check_note_dismissed';

/// The one-time paid unlock's local entitlement flag (this slice) — see
/// `lib/data/repository/entitlement_repository.dart` for the full
/// rationale. Deliberately in this same generic table, not a bespoke
/// column/table of its own: it's exactly the same shape of thing as the
/// Health check flag above (a single per-install boolean), and the whole
/// point of this table existing is to avoid a proliferation of one-off
/// tables for small flags like this.
const String kEntitlementKey = 'paid_entitlement';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Live version of [getValue] — the entitlement flag (and anything else
  /// added here later) needs to be watchable so the UI reacts to a
  /// purchase/restore/entitlement-loss the moment it's persisted, the same
  /// way [RenewalDao.watchItemById] already drives item detail's four
  /// states off a live stream rather than a one-off read.
  Stream<String?> watchValue(String key) =>
      (select(appSettings)..where((t) => t.key.equals(key))).watchSingleOrNull().map((row) => row?.value);

  Future<void> setValue(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
  }

  Future<bool> isHealthCheckNoteDismissed() async {
    final value = await getValue(kHealthCheckNoteDismissedKey);
    return value == 'true';
  }

  Future<void> setHealthCheckNoteDismissed() => setValue(kHealthCheckNoteDismissedKey, 'true');
}
