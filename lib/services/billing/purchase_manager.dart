import 'dart:async';

import '../../data/repository/entitlement_repository.dart';
import '../notifications/reconciliation_service.dart';
import 'billing_gateway.dart';

/// The impure half of the entitlement mechanism, mirroring how
/// `ReconciliationService` relates to `ReconciliationPlanner`: this is the
/// one place a purchase/restore update, wherever it originated (the
/// paywall screen, Settings' Restore purchase tile, or — a real Play
/// Billing possibility — a [PurchaseResultKind.pending] purchase clearing
/// on its own well after the user has closed both screens) actually gets
/// turned into a persisted entitlement change plus a rescheduling pass.
///
/// Constructed once and subscribed for the app's lifetime (see `app.dart`,
/// same lifecycle as [ReconciliationService]/`NotificationService`'s live
/// callback) — **not** scoped to the paywall screen, specifically so a
/// [PurchaseResultKind.pending] purchase that clears after the user has
/// navigated away still gets applied. [PaywallController] listens to the
/// same broadcast [BillingGateway.purchaseUpdates] stream independently,
/// purely to drive its own on-screen state machine — this class never
/// touches UI state.
class PurchaseManager {
  PurchaseManager({
    required BillingGateway billingGateway,
    required EntitlementRepository entitlementRepository,
    required ReconciliationService reconciliationService,
  })  : _billingGateway = billingGateway,
        _entitlementRepository = entitlementRepository,
        _reconciliationService = reconciliationService;

  final BillingGateway _billingGateway;
  final EntitlementRepository _entitlementRepository;
  final ReconciliationService _reconciliationService;

  StreamSubscription<List<PurchaseUpdateRecord>>? _subscription;

  /// Must run after [BillingGateway.init]. Safe to call once.
  Future<void> start() async {
    _subscription ??= _billingGateway.purchaseUpdates.listen(_handleUpdates);
  }

  Future<void> _handleUpdates(List<PurchaseUpdateRecord> updates) async {
    var grantedAny = false;
    for (final update in updates) {
      if (update.productId != kUnlockProductId) continue; // this app has exactly one SKU

      switch (update.kind) {
        case PurchaseResultKind.purchased:
        case PurchaseResultKind.restored:
          grantedAny = true;
          if (update.pendingCompletion) await _billingGateway.completePurchase(update);
        case PurchaseResultKind.pending:
        case PurchaseResultKind.error:
        case PurchaseResultKind.canceled:
          // Nothing to persist — REQ-17.3's "must degrade safely, never
          // delete data" is about entitlement being *lost*, which none of
          // these three represent; they just mean entitlement was never
          // (yet) granted by this particular update.
          break;
      }
    }

    if (!grantedAny) return;
    await _entitlementRepository.setEntitled(true);
    // REQ-14.2 — the real integration point: the very next reconciliation
    // pass reads the now-true entitlement flag and (via
    // ReconciliationPlanner) recomputes every existing item's full paid
    // ladder + overdue follow-through, scheduling only what's still ahead
    // of "now" — no separate "apply purchase effects" code path needed.
    await _reconciliationService.reconcile();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
