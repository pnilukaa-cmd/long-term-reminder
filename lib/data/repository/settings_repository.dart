import '../database/settings_dao.dart';

/// Thin wrapper over [SettingsDao] for the small set of per-install flags
/// this slice needs (currently just the Health check one-time note,
/// REQ-1.2).
class SettingsRepository {
  SettingsRepository(this._dao);

  final SettingsDao _dao;

  Future<bool> isHealthCheckNoteDismissed() => _dao.isHealthCheckNoteDismissed();

  Future<void> dismissHealthCheckNote() => _dao.setHealthCheckNoteDismissed();
}
