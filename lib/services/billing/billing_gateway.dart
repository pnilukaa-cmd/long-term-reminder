/// The single one-time non-consumable SKU this app sells, per
/// `CLAUDE.md`'s Stack section (direct Play Billing via `in_app_purchase`,
/// not RevenueCat) and `docs/product/01-v1-scope.md` §2.
const String kUnlockProductId = 'full_ladder_unlock';

/// A product's store-reported details — just enough for the paywall to
/// render a real price (REQ-14.1's `$3.99 one-time`, sourced live from the
/// store rather than hardcoded, since Play lets a developer change price
/// without an app update). Deliberately a tiny, app-owned shape rather
/// than exposing `in_app_purchase`'s own `ProductDetails` class outside
/// this directory — the interface below has zero dependency on that
/// package, which is what makes [FakeBillingGateway] possible.
class BillingProductInfo {
  const BillingProductInfo({required this.id, required this.title, required this.formattedPrice});

  final String id;
  final String title;

  /// Store-formatted, currency-symbol-included price string (e.g.
  /// `"$3.99"`) — never a raw number this app would have to guess a
  /// currency symbol for.
  final String formattedPrice;
}

/// The handful of outcomes a purchase attempt can resolve to — deliberately
/// richer than a bare success/failure boolean, per the task brief's "handle
/// the states billing actually has: loading, unavailable, pending,
/// purchased, error, and cancelled-by-user."
enum PurchaseResultKind {
  /// Purchase completed (a fresh buy, or a previously-owned purchase
  /// surfaced by a restore/relaunch query — `in_app_purchase` reports both
  /// through the same `PurchaseStatus.purchased`/`.restored` values on the
  /// same stream).
  purchased,

  /// Same practical outcome as [purchased] (entitlement should be granted),
  /// but explicitly the result of a *restore* call rather than a fresh buy
  /// — kept distinct so [PurchaseManager]/`PaywallController` can log/report
  /// which path actually granted entitlement without re-deriving it.
  restored,

  /// Play returned `PurchaseStatus.pending` — a real, documented state for
  /// payment methods that don't clear instantly (e.g. certain carrier
  /// billing or cash-based methods). Entitlement is **not** granted yet;
  /// the store is expected to deliver a follow-up [purchased] update on
  /// this same stream once it clears, with no further action needed from
  /// this app.
  pending,

  /// The purchase failed for a real reason (network, declined payment,
  /// billing unavailable mid-flow, etc.).
  error,

  /// The user backed out of Play's own purchase sheet. Deliberately **not**
  /// modelled as [error] — REQ-14's spirit ("a purchase that silently does
  /// nothing is worse than one that fails loudly") is about failures the
  /// user didn't choose; a deliberate cancel is not a failure and should
  /// read differently in the UI.
  canceled,
}

/// One purchase-stream update for [kUnlockProductId]. Mirrors the shape of
/// `in_app_purchase`'s `PurchaseDetails` closely enough to translate
/// 1:1 in [PlayBillingGateway], but — same reasoning as
/// [BillingProductInfo] — owned by this app so the interface and every
/// caller of it stay independent of the plugin.
class PurchaseUpdateRecord {
  const PurchaseUpdateRecord({
    required this.productId,
    required this.kind,
    this.errorMessage,
    this.pendingCompletion = false,
  });

  final String productId;
  final PurchaseResultKind kind;

  /// Set only for [PurchaseResultKind.error] — a short, user-presentable
  /// reason where the platform provides one; may be null even on error.
  final String? errorMessage;

  /// True when this update still needs [BillingGateway.completePurchase]
  /// called on it (`in_app_purchase`'s own `pendingCompletePurchase` flag)
  /// — Android requires every purchase to be acknowledged within 3 days or
  /// Play automatically refunds it, so this is not optional bookkeeping.
  final bool pendingCompletion;
}

/// The seam named in the developer task brief: "Put the `in_app_purchase`
/// calls behind an interface with a fake implementation for tests, so
/// gating logic is testable without a store." Every method here is
/// deliberately narrow and product-id-scoped — nothing in this interface
/// (or anything that implements it) ever accepts or transmits renewal
/// data, which is what keeps the privacy policy's "the billing call is
/// scoped to whether the entitlement exists, never to any renewal item"
/// claim literally true in code, not just in prose.
abstract class BillingGateway {
  /// Registers plugin-level plumbing (on [PlayBillingGateway], subscribing
  /// to the platform's own purchase stream). Safe to call once, before
  /// anything else on this interface is used.
  Future<void> init();

  /// Whether in-app purchases are usable at all on this device/build (e.g.
  /// false with no Play Store installed, signed out, or on an unsupported
  /// build channel) — REQ-14's `unavailable` state, distinct from a
  /// purchase attempt failing.
  Future<bool> isAvailable();

  /// Store-reported details for [kUnlockProductId], or null if the store
  /// doesn't recognize the SKU (e.g. not yet configured in Play Console —
  /// a real possibility before the first production listing goes live).
  /// Also treated as an `unavailable`-shaped state by the caller, not a
  /// hard error.
  Future<BillingProductInfo?> queryProduct();

  /// Every purchase-lifecycle update for any product this app has ever
  /// touched, for the lifetime of the app process — a broadcast stream so
  /// both `PurchaseManager` (persists entitlement) and `PaywallController`
  /// (drives the on-screen state machine) can each listen independently,
  /// mirroring `in_app_purchase`'s own `purchaseStream` shape.
  Stream<List<PurchaseUpdateRecord>> get purchaseUpdates;

  /// Kicks off the OS purchase sheet for [kUnlockProductId]. Returns once
  /// the *request* has been sent, not once it resolves — the actual
  /// outcome always arrives asynchronously via [purchaseUpdates], exactly
  /// mirroring `in_app_purchase.buyNonConsumable`'s own fire-and-forget
  /// contract (there is no synchronous "did it succeed" return value on
  /// real Play Billing).
  Future<void> buy();

  /// Asks the store to re-deliver any purchase this Google account already
  /// owns. Same fire-and-forget contract as [buy] — matching updates (if
  /// any exist) arrive via [purchaseUpdates] as [PurchaseResultKind.restored].
  /// **Known, documented rough edge, stated here rather than discovered
  /// silently:** if nothing is owned, Play does not send any stream event
  /// at all — there is no explicit "nothing to restore" signal from the
  /// platform. Callers must use a timeout (see `PaywallController`) to
  /// distinguish "genuinely nothing owned" from "still in flight."
  Future<void> restore();

  /// Acknowledges a purchase update whose [PurchaseUpdateRecord.pendingCompletion]
  /// is true — required by Android within 3 days of purchase or Play
  /// auto-refunds it.
  Future<void> completePurchase(PurchaseUpdateRecord record);

  /// Releases the underlying stream subscription — mirrors every other
  /// service in this codebase that owns a subscription
  /// (`ReconciliationService` has no teardown need, but `UndoController`/
  /// `NotificationService`'s callback fields are the closer precedent).
  void dispose();
}
