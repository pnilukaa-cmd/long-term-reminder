import '../database/settings_dao.dart';

/// Local, offline-first source of truth for the one-time paid unlock.
///
/// Per `CLAUDE.md`'s Stack section and the developer task brief: the app
/// must know whether the user has paid **without a network call** — Play
/// Billing's own purchase-verification call happens separately (see
/// `lib/services/billing/`), but the *gating decision itself* (what
/// [ReconciliationPlanner]/item detail/Add-Edit actually render and
/// schedule) is always answered from this local flag, persisted in the
/// same generic key/value table the Health check one-time note already
/// uses (`lib/data/database/settings_dao.dart`).
///
/// This is a single global flag, not per-item — this app sells one SKU
/// ("unlock everything"), not per-item entitlement, per
/// `docs/product/01-v1-scope.md` §2.
class EntitlementRepository {
  EntitlementRepository(this._dao);

  final SettingsDao _dao;

  Future<bool> isEntitled() async {
    final value = await _dao.getValue(kEntitlementKey);
    return value == 'true';
  }

  /// Live version of [isEntitled] — every screen that needs to react to a
  /// purchase/restore/entitlement-loss the moment it happens (item detail's
  /// ladder track, Add/Edit's ladder preview, Settings' purchase group)
  /// watches this instead of doing a one-off read, the same way the rest of
  /// this app is built around live drift streams rather than manual
  /// refresh calls.
  Stream<bool> watchEntitled() => _dao.watchValue(kEntitlementKey).map((v) => v == 'true');

  /// Sets the local entitlement flag directly. Used by
  /// [lib/services/billing/purchase_manager.dart]'s `PurchaseManager` once
  /// a purchase/restore update actually confirms ownership, and by the
  /// `kDebugMode`-gated debug screen (developer task brief — REQ-17.3 is
  /// otherwise unverifiable without a real Play Console purchase) to let a
  /// human exercise the "loss of entitlement degrades gracefully, deletes
  /// nothing" path on demand.
  Future<void> setEntitled(bool value) => _dao.setValue(kEntitlementKey, value ? 'true' : 'false');
}
