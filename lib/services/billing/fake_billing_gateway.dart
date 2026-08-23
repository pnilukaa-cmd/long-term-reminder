import 'dart:async';

import 'billing_gateway.dart';

/// Test double for [BillingGateway] — the developer task brief's explicit
/// instruction: "make the entitlement layer testable in isolation with a
/// fake, so the untestable part is as thin as possible." Every method a
/// test would want to control is a plain, synchronous field/method here;
/// nothing about this class talks to a platform channel, so it runs
/// identically in this sandboxed environment and on a real device — which
/// is exactly the point.
///
/// **Never wired into `main.dart`/production code** — see
/// `PlayBillingGateway` for the real (unverified — no device in this
/// environment) implementation.
class FakeBillingGateway implements BillingGateway {
  bool available = true;

  /// Null simulates "the store doesn't recognize this SKU" (REQ-14's
  /// `unavailable` state via a missing product, distinct from
  /// [available] being false outright).
  BillingProductInfo? product = const BillingProductInfo(
    id: kUnlockProductId,
    title: 'Full ladder unlock',
    formattedPrice: '\$3.99',
  );

  bool initCalled = false;
  int buyCallCount = 0;
  int restoreCallCount = 0;
  final List<PurchaseUpdateRecord> completedRecords = [];

  final _controller = StreamController<List<PurchaseUpdateRecord>>.broadcast();

  @override
  Stream<List<PurchaseUpdateRecord>> get purchaseUpdates => _controller.stream;

  @override
  Future<void> init() async => initCalled = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BillingProductInfo?> queryProduct() async => product;

  /// What [buy] emits on [purchaseUpdates] once called — defaults to a
  /// clean purchase. Tests override this before calling `buy()` to
  /// exercise the error/pending/cancelled paths (e.g.
  /// `gateway.nextBuyOutcome = PurchaseUpdateRecord(... kind: PurchaseResultKind.error)`).
  PurchaseUpdateRecord? nextBuyOutcome = const PurchaseUpdateRecord(
    productId: kUnlockProductId,
    kind: PurchaseResultKind.purchased,
    pendingCompletion: true,
  );

  /// Same idea as [nextBuyOutcome] but for [restore] — defaults to null
  /// (nothing owned, no stream event at all), matching the real plugin's
  /// documented behaviour that a restore with nothing to restore produces
  /// silence, not an explicit "not found" signal (see [BillingGateway.restore]'s
  /// doc comment).
  PurchaseUpdateRecord? nextRestoreOutcome;

  /// How long to wait before emitting the queued outcome — 0 by default so
  /// most tests don't need `pumpAndSettle`/timers at all; a few tests set
  /// this to exercise the "still in flight" moment of the state machine.
  Duration emitDelay = Duration.zero;

  @override
  Future<void> buy() async {
    buyCallCount++;
    final outcome = nextBuyOutcome;
    if (outcome == null) return;
    if (emitDelay == Duration.zero) {
      _controller.add([outcome]);
    } else {
      unawaited(Future.delayed(emitDelay, () => _controller.add([outcome])));
    }
  }

  @override
  Future<void> restore() async {
    restoreCallCount++;
    final outcome = nextRestoreOutcome;
    if (outcome == null) return; // matches real Play: silence, no event
    if (emitDelay == Duration.zero) {
      _controller.add([outcome]);
    } else {
      unawaited(Future.delayed(emitDelay, () => _controller.add([outcome])));
    }
  }

  @override
  Future<void> completePurchase(PurchaseUpdateRecord record) async {
    completedRecords.add(record);
  }

  /// Lets a test simulate an update arriving with no [buy]/[restore] call
  /// having triggered it — e.g. a delayed [PurchaseResultKind.pending]
  /// purchase clearing later in the app's lifetime.
  void emit(PurchaseUpdateRecord record) => _controller.add([record]);

  @override
  void dispose() => _controller.close();
}
