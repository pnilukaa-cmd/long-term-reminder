import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_gateway.dart';

/// The real [BillingGateway], direct Play Billing via Flutter's official
/// `in_app_purchase` plugin — per `CLAUDE.md`'s Stack section (this
/// overturned a prior RevenueCat default specifically because a single
/// one-time non-consumable SKU doesn't need RevenueCat's cross-platform/
/// subscription complexity).
///
/// **Unverified, per the honesty constraint on this slice**: no Flutter
/// SDK, no device, no emulator, and — the constraint specific to billing
/// code — no Play Console setup (no uploaded build, no configured SKU, no
/// licence testers) exist in this environment. This is written to
/// `in_app_purchase`'s documented API surface (`InAppPurchase.instance`,
/// `purchaseStream`, `queryProductDetails`, `buyNonConsumable`,
/// `restorePurchases`, `completePurchase`) but none of it has been
/// resolved against an installed package version, run against a real
/// Play Billing sandbox, or exercised with a real signed build. This is
/// exactly why every entitlement/gating decision that actually matters
/// (`ReconciliationPlanner`, `PurchaseManager`, `PaywallController`) is
/// built and tested against [BillingGateway]'s interface with
/// [FakeBillingGateway] instead of depending on this class ever having
/// run — see the developer handoff for the explicit list of what remains
/// genuinely unverifiable without a Play Console setup.
class PlayBillingGateway implements BillingGateway {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _controller = StreamController<List<PurchaseUpdateRecord>>.broadcast();

  /// The plugin's own `PurchaseDetails` object for every update this
  /// gateway has seen with `pendingCompletePurchase == true`, keyed by
  /// product id — `in_app_purchase.completePurchase()` needs that exact
  /// object (verification data and all), not just a product id, and the
  /// plugin gives no supported way to reconstruct one by hand. Populated
  /// in [init]'s listener, consumed (and removed) by [completePurchase].
  final Map<String, PurchaseDetails> _pendingDetails = {};

  @override
  Stream<List<PurchaseUpdateRecord>> get purchaseUpdates => _controller.stream;

  @override
  Future<void> init() async {
    if (_subscription != null) return;
    _subscription = _iap.purchaseStream.listen(
      (updates) {
        for (final details in updates) {
          if (details.pendingCompletePurchase) _pendingDetails[details.productID] = details;
        }
        _controller.add(updates.map(_toRecord).toList(growable: false));
      },
      onError: (Object error) {
        // The stream itself erroring (rather than an individual purchase)
        // is not a documented normal case, but per the task brief's "a
        // purchase that silently does nothing is worse than one that
        // fails loudly," surface it as a single error record for whatever
        // this app's one SKU is, rather than letting it vanish.
        _controller.add([
          PurchaseUpdateRecord(
            productId: kUnlockProductId,
            kind: PurchaseResultKind.error,
            errorMessage: error.toString(),
          ),
        ]);
      },
    );
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<BillingProductInfo?> queryProduct() async {
    final response = await _iap.queryProductDetails({kUnlockProductId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    final details = response.productDetails.first;
    return BillingProductInfo(id: details.id, title: details.title, formattedPrice: details.price);
  }

  @override
  Future<void> buy() async {
    final response = await _iap.queryProductDetails({kUnlockProductId});
    if (response.productDetails.isEmpty) {
      _controller.add([
        const PurchaseUpdateRecord(
          productId: kUnlockProductId,
          kind: PurchaseResultKind.error,
          errorMessage: 'Product not found — check the Play Console SKU configuration.',
        ),
      ]);
      return;
    }
    final purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    // Non-consumable, one-time unlock — never `buyConsumable`. The actual
    // result always arrives via [purchaseUpdates]; this call only sends
    // the request (see [BillingGateway.buy]'s doc comment).
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseUpdateRecord record) async {
    // See [_pendingDetails]'s doc comment — this is why [init]'s listener
    // caches the raw plugin object instead of this method trying to
    // reconstruct one. `PurchaseManager` is expected to call this only for
    // a record it just received from [purchaseUpdates], so the cache
    // should always have a match here in practice; a miss (already
    // completed, or somehow never cached) is a silent no-op rather than a
    // thrown error, since there's nothing further this app can do about a
    // completion it has no plugin object for.
    final match = _pendingDetails.remove(record.productId);
    if (match != null) await _iap.completePurchase(match);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  PurchaseUpdateRecord _toRecord(PurchaseDetails details) {
    final kind = switch (details.status) {
      PurchaseStatus.purchased => PurchaseResultKind.purchased,
      PurchaseStatus.restored => PurchaseResultKind.restored,
      PurchaseStatus.pending => PurchaseResultKind.pending,
      PurchaseStatus.error => PurchaseResultKind.error,
      PurchaseStatus.canceled => PurchaseResultKind.canceled,
    };
    return PurchaseUpdateRecord(
      productId: details.productID,
      kind: kind,
      errorMessage: details.error?.message,
      pendingCompletion: details.pendingCompletePurchase,
    );
  }
}
