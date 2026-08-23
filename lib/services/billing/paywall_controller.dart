import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repository/entitlement_repository.dart';
import '../notifications/reconciliation_service.dart';
import 'billing_gateway.dart';

/// Every state the paywall screen can actually be in — REQ-14.1's four
/// mocked states (`loading`/`ready`≈default/`error`/`success`) plus the
/// three more the developer task brief explicitly calls out as real
/// billing states a silent-failure paywall would otherwise hide:
/// `unavailable` (billing/product genuinely not usable right now, not a
/// failed purchase attempt), `pending` (Play's own deferred-purchase
/// state), and `cancelled` (the user backed out of Play's own purchase
/// sheet — a deliberate choice, not a failure, and rendered differently
/// from [error] for exactly that reason).
enum PaywallStatus { loading, unavailable, ready, busy, pending, cancelled, error, success }

/// Owns the paywall's whole state machine, independent of any widget —
/// genuinely unit-testable with [FakeBillingGateway] and an in-memory
/// database, per the developer task brief's core instruction for this
/// slice ("make the entitlement layer testable in isolation with a fake,
/// so the untestable part is as thin as possible"). The only untestable
/// part left is [PlayBillingGateway] itself.
///
/// Two independent listeners exist on [BillingGateway.purchaseUpdates] by
/// design — this class's own (drives on-screen state) and
/// [PurchaseManager]'s (persists entitlement, reconciles). Neither is
/// responsible for the other's job; see [PurchaseManager]'s class doc for
/// the full reasoning.
class PaywallController extends ChangeNotifier {
  PaywallController({
    required this.billingGateway,
    required this.entitlementRepository,
    required this.reconciliationService,
    this.restoreTimeout = const Duration(seconds: 6),
  });

  final BillingGateway billingGateway;
  final EntitlementRepository entitlementRepository;
  final ReconciliationService reconciliationService;

  /// **Unverified against a real Play Billing sandbox** — `restore()`
  /// documented behaviour is "silence if nothing is owned" (see
  /// [BillingGateway.restore]), so this is the only way to resolve
  /// "restoring" into a definite outcome. 6 seconds is a guess (in line
  /// with this app's existing 6-second undo-toast window elsewhere, for
  /// no reason beyond "a number already established as reasonable in this
  /// codebase") — flagged explicitly for tuning once real device/network
  /// latency is observable. An instance field, not a constant, specifically
  /// so tests can inject a near-zero duration rather than a real test
  /// actually waiting 6 seconds wall-clock time.
  final Duration restoreTimeout;

  PaywallStatus status = PaywallStatus.loading;
  BillingProductInfo? product;
  String? message;

  /// True when [status] is [PaywallStatus.success] because [load] found
  /// the user already entitled (Settings → Paywall while already
  /// unlocked, or reopening the paywall after a purchase already landed)
  /// rather than because a purchase/restore just completed in this
  /// session — lets the screen say "You're already unlocked" instead of
  /// "You're set" without a separate status value.
  bool alreadyOwned = false;

  StreamSubscription<List<PurchaseUpdateRecord>>? _subscription;
  Timer? _restoreTimeoutTimer;
  bool _restoreInFlight = false;

  /// Loads (or reloads) the screen's initial state. Safe to call more than
  /// once (e.g. a manual "Try again").
  Future<void> load() async {
    status = PaywallStatus.loading;
    message = null;
    notifyListeners();

    _subscription ??= billingGateway.purchaseUpdates.listen(_handleUpdates);

    try {
      // Deliberately checked first, and answered entirely from the local
      // flag (per `CLAUDE.md`'s Stack section / REQ-15.2 — this app must
      // never need a network call just to know the user has paid). If
      // already entitled, there's no reason to hit the store at all.
      if (await entitlementRepository.isEntitled()) {
        alreadyOwned = true;
        status = PaywallStatus.success;
        notifyListeners();
        return;
      }

      if (!await billingGateway.isAvailable()) {
        status = PaywallStatus.unavailable;
        message = "In-app purchases aren't available right now — check you're signed into the Play Store and try "
            'again.';
        notifyListeners();
        return;
      }

      final details = await billingGateway.queryProduct();
      if (details == null) {
        status = PaywallStatus.unavailable;
        message = "Couldn't load the unlock's price right now — check your connection and try again.";
        notifyListeners();
        return;
      }

      product = details;
      status = PaywallStatus.ready;
      notifyListeners();
    } catch (_) {
      status = PaywallStatus.unavailable;
      message = "Couldn't reach the Play Store — check your connection and try again.";
      notifyListeners();
    }
  }

  Future<void> buy() async {
    if (status == PaywallStatus.busy) return;
    _restoreInFlight = false;
    status = PaywallStatus.busy;
    message = null;
    notifyListeners();
    try {
      await billingGateway.buy();
      // The actual outcome (purchased/pending/error/cancelled) always
      // arrives asynchronously via [_handleUpdates] — see
      // [BillingGateway.buy]'s doc comment. Unlike [restore], a real Play
      // purchase-sheet attempt always resolves one way or another, so no
      // timeout fallback is needed here.
    } catch (_) {
      status = PaywallStatus.error;
      message = "Purchase didn't go through — you haven't been charged. Check your connection and try again.";
      notifyListeners();
    }
  }

  /// REQ-14.3, reachable from both the paywall screen and Settings — see
  /// `SettingsScreen`, which constructs a short-lived [PaywallController]
  /// purely to call this and read back the settled [status]/[message]
  /// rather than duplicating this timeout logic.
  Future<void> restore() async {
    if (status == PaywallStatus.busy) return;
    _restoreInFlight = true;
    status = PaywallStatus.busy;
    message = null;
    notifyListeners();
    try {
      await billingGateway.restore();
    } catch (_) {
      status = PaywallStatus.error;
      message = "Couldn't check for a previous purchase — check your connection and try again.";
      notifyListeners();
      return;
    }
    _restoreTimeoutTimer?.cancel();
    _restoreTimeoutTimer = Timer(restoreTimeout, _handleRestoreTimeout);
  }

  /// Awaits [restore] settling into a terminal status (anything but
  /// [PaywallStatus.busy]) — the shape `SettingsScreen`'s non-navigating
  /// "Restore purchase" tile needs, since it just wants a final
  /// success/error/pending message for a SnackBar, not a live-rebuilding
  /// widget subscribed to this controller.
  Future<PaywallStatus> restoreAndAwaitResult() async {
    await restore();
    if (status != PaywallStatus.busy) return status;
    final completer = Completer<PaywallStatus>();
    void listener() {
      if (status == PaywallStatus.busy) return;
      completer.complete(status);
    }

    addListener(listener);
    final result = await completer.future;
    removeListener(listener);
    return result;
  }

  void _handleRestoreTimeout() {
    // An update already resolved this in the meantime — nothing to do.
    if (status != PaywallStatus.busy || !_restoreInFlight) return;
    status = PaywallStatus.error;
    message = "Nothing to restore — you haven't unlocked this on this Google account yet.";
    notifyListeners();
  }

  void _handleUpdates(List<PurchaseUpdateRecord> updates) {
    for (final update in updates) {
      if (update.productId != kUnlockProductId) continue; // this app has exactly one SKU
      _restoreTimeoutTimer?.cancel();

      switch (update.kind) {
        case PurchaseResultKind.purchased:
        case PurchaseResultKind.restored:
          status = PaywallStatus.success;
          alreadyOwned = false;
          message = null;
        case PurchaseResultKind.pending:
          status = PaywallStatus.pending;
          message = "Purchase pending — this can take a little while to clear. We'll unlock everything "
              'automatically once it does; you can close this and keep using the app.';
        case PurchaseResultKind.error:
          status = PaywallStatus.error;
          message = update.errorMessage ??
              "Purchase didn't go through — you haven't been charged. Check your connection and try again.";
        case PurchaseResultKind.canceled:
          status = PaywallStatus.cancelled;
          message = "Purchase cancelled — you haven't been charged.";
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _restoreTimeoutTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
