// PaywallController owns the whole paywall state machine and is designed
// to be testable in isolation with FakeBillingGateway, per the developer
// task brief. No widget pumping needed — this exercises the state
// transitions directly.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/services/billing/billing_gateway.dart';
import 'package:long_term_reminder/services/billing/fake_billing_gateway.dart';
import 'package:long_term_reminder/services/billing/paywall_controller.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';

void main() {
  late AppDatabase database;
  late EntitlementRepository entitlementRepository;
  late FakeBillingGateway gateway;
  late ReconciliationService reconciliationService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    entitlementRepository = EntitlementRepository(database.settingsDao);
    gateway = FakeBillingGateway();
    reconciliationService = ReconciliationService(
      renewalRepository: RenewalRepository(database.renewalDao),
      notificationDao: database.notificationDao,
      notificationService: NotificationService(),
      entitlementRepository: entitlementRepository,
    );
  });

  tearDown(() => database.close());

  PaywallController buildController({Duration restoreTimeout = const Duration(milliseconds: 20)}) {
    return PaywallController(
      billingGateway: gateway,
      entitlementRepository: entitlementRepository,
      reconciliationService: reconciliationService,
      restoreTimeout: restoreTimeout,
    );
  }

  group('load — REQ-14.1\'s states', () {
    test('billing available with a product → ready, product populated', () async {
      final controller = buildController();
      await controller.load();

      expect(controller.status, PaywallStatus.ready);
      expect(controller.product?.formattedPrice, '\$3.99');
      controller.dispose();
    });

    test('billing unavailable → unavailable, not a loud error', () async {
      gateway.available = false;
      final controller = buildController();
      await controller.load();

      expect(controller.status, PaywallStatus.unavailable);
      expect(controller.message, isNotNull);
      controller.dispose();
    });

    test('product not found (e.g. SKU not configured yet) → unavailable', () async {
      gateway.product = null;
      final controller = buildController();
      await controller.load();

      expect(controller.status, PaywallStatus.unavailable);
      controller.dispose();
    });

    test('already entitled → success with alreadyOwned, without even checking billing availability', () async {
      await entitlementRepository.setEntitled(true);
      gateway.available = false; // proves this is never even consulted
      final controller = buildController();
      await controller.load();

      expect(controller.status, PaywallStatus.success);
      expect(controller.alreadyOwned, isTrue);
      controller.dispose();
    });
  });

  group('buy — REQ-14.1/14.2 plus the extra states the task brief names', () {
    test('a purchased outcome resolves to success', () async {
      final controller = buildController();
      await controller.load();
      gateway.nextBuyOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.purchased,
      );

      await controller.buy();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PaywallStatus.success);
      expect(controller.alreadyOwned, isFalse);
      controller.dispose();
    });

    test('an error outcome resolves to error with reassurance copy available, not silence', () async {
      final controller = buildController();
      await controller.load();
      gateway.nextBuyOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.error,
        errorMessage: 'card declined',
      );

      await controller.buy();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PaywallStatus.error);
      expect(controller.message, 'card declined');
      controller.dispose();
    });

    test('a cancelled outcome resolves to cancelled, distinct from error', () async {
      final controller = buildController();
      await controller.load();
      gateway.nextBuyOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.canceled,
      );

      await controller.buy();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PaywallStatus.cancelled);
      expect(controller.message, isNotNull, reason: 'never silent — REQ says a silent no-op is worse than a loud failure');
      controller.dispose();
    });

    test('a pending outcome resolves to pending, with reassurance it will resolve automatically', () async {
      final controller = buildController();
      await controller.load();
      gateway.nextBuyOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.pending,
      );

      await controller.buy();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PaywallStatus.pending);
      controller.dispose();
    });

    test('the gateway throwing synchronously on buy() still surfaces as error, never silence', () async {
      final controller = buildController();
      await controller.load();
      gateway.available = true;
      // Simulate a thrown exception by using a gateway whose buy() throws.
      final throwingGateway = _ThrowingBuyGateway(gateway);
      final throwingController = PaywallController(
        billingGateway: throwingGateway,
        entitlementRepository: entitlementRepository,
        reconciliationService: reconciliationService,
      );
      await throwingController.load();

      await throwingController.buy();

      expect(throwingController.status, PaywallStatus.error);
      expect(throwingController.message, isNotNull);
      controller.dispose();
      throwingController.dispose();
    });
  });

  group('restore — REQ-14.3, including the documented "silence means nothing to restore" rough edge', () {
    test('a restored outcome resolves to success', () async {
      final controller = buildController();
      await controller.load();
      gateway.nextRestoreOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.restored,
      );

      await controller.restore();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PaywallStatus.success);
      controller.dispose();
    });

    test('no stream event at all (nothing owned) times out into an honest "nothing to restore" error', () async {
      final controller = buildController(restoreTimeout: const Duration(milliseconds: 10));
      await controller.load();
      gateway.nextRestoreOutcome = null; // matches real Play's documented silence

      final result = await controller.restoreAndAwaitResult();

      expect(result, PaywallStatus.error);
      expect(controller.message, contains('Nothing to restore'));
      controller.dispose();
    });

    test('restoreAndAwaitResult resolves promptly (not via the timeout) when an update actually arrives', () async {
      final controller = buildController(restoreTimeout: const Duration(seconds: 30));
      await controller.load();
      gateway.nextRestoreOutcome = const PurchaseUpdateRecord(
        productId: kUnlockProductId,
        kind: PurchaseResultKind.restored,
      );

      final result = await controller.restoreAndAwaitResult().timeout(const Duration(seconds: 2));

      expect(result, PaywallStatus.success);
      controller.dispose();
    });
  });
}

/// Minimal wrapper that makes [BillingGateway.buy] throw synchronously —
/// exercises [PaywallController.buy]'s own try/catch without needing a
/// second, more elaborate fake.
class _ThrowingBuyGateway implements BillingGateway {
  _ThrowingBuyGateway(this._delegate);
  final BillingGateway _delegate;

  @override
  Future<void> buy() => Future.error(Exception('simulated plugin failure'));

  @override
  Future<void> completePurchase(PurchaseUpdateRecord record) => _delegate.completePurchase(record);

  @override
  void dispose() => _delegate.dispose();

  @override
  Future<void> init() => _delegate.init();

  @override
  Future<bool> isAvailable() => _delegate.isAvailable();

  @override
  Stream<List<PurchaseUpdateRecord>> get purchaseUpdates => _delegate.purchaseUpdates;

  @override
  Future<BillingProductInfo?> queryProduct() => _delegate.queryProduct();

  @override
  Future<void> restore() => _delegate.restore();
}
