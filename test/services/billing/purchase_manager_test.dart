// PurchaseManager is the impure half of the entitlement mechanism — the
// developer task brief's core instruction for this slice: "make the
// entitlement layer testable in isolation with a fake, so the untestable
// part is as thin as possible." Every test here runs against
// [FakeBillingGateway] and an in-memory database — none of it needs a
// device, an emulator, or a Play Console setup.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/services/billing/billing_gateway.dart';
import 'package:long_term_reminder/services/billing/fake_billing_gateway.dart';
import 'package:long_term_reminder/services/billing/purchase_manager.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';

void main() {
  late AppDatabase database;
  late EntitlementRepository entitlementRepository;
  late RenewalRepository renewalRepository;
  late FakeBillingGateway gateway;
  late ReconciliationService reconciliationService;
  late PurchaseManager manager;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    entitlementRepository = EntitlementRepository(database.settingsDao);
    renewalRepository = RenewalRepository(database.renewalDao);
    gateway = FakeBillingGateway();
    reconciliationService = ReconciliationService(
      renewalRepository: renewalRepository,
      notificationDao: database.notificationDao,
      notificationService: NotificationService(), // never .init()-ed; reconcile() only touches the DB in these tests
      entitlementRepository: entitlementRepository,
    );
    manager = PurchaseManager(
      billingGateway: gateway,
      entitlementRepository: entitlementRepository,
      reconciliationService: reconciliationService,
    );
  });

  tearDown(() {
    manager.dispose();
    database.close();
  });

  test('a purchased update grants entitlement and completes the purchase', () async {
    await manager.start();
    expect(await entitlementRepository.isEntitled(), isFalse);

    gateway.emit(const PurchaseUpdateRecord(
      productId: kUnlockProductId,
      kind: PurchaseResultKind.purchased,
      pendingCompletion: true,
    ));
    await Future<void>.delayed(Duration.zero); // let the async handler run

    expect(await entitlementRepository.isEntitled(), isTrue);
    expect(gateway.completedRecords, hasLength(1));
  });

  test('a restored update grants entitlement exactly like a purchased one', () async {
    await manager.start();

    gateway.emit(const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.restored));
    await Future<void>.delayed(Duration.zero);

    expect(await entitlementRepository.isEntitled(), isTrue);
  });

  test('a pending update grants nothing — the follow-up purchased update is what matters', () async {
    await manager.start();

    gateway.emit(const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.pending));
    await Future<void>.delayed(Duration.zero);
    expect(await entitlementRepository.isEntitled(), isFalse);

    gateway.emit(const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.purchased));
    await Future<void>.delayed(Duration.zero);
    expect(await entitlementRepository.isEntitled(), isTrue);
  });

  test('an error or cancelled update grants nothing', () async {
    await manager.start();

    gateway.emit(const PurchaseUpdateRecord(
      productId: kUnlockProductId,
      kind: PurchaseResultKind.error,
      errorMessage: 'simulated',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(await entitlementRepository.isEntitled(), isFalse);

    gateway.emit(const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.canceled));
    await Future<void>.delayed(Duration.zero);
    expect(await entitlementRepository.isEntitled(), isFalse);
  });

  test(
    'REQ-14.2 — granting entitlement immediately reschedules an existing item to its full paid ladder',
    () async {
      final id = await renewalRepository.createItem(
        type: RenewalType.vehicle,
        label: 'MOT',
        dueDate: DateTime.now().add(const Duration(days: 60)),
      );
      await reconciliationService.reconcile(); // free-tier baseline

      var rows = await database.notificationDao.getRowsForRenewal(id);
      expect(rows, hasLength(1), reason: 'free tier gets exactly one reminder');

      await manager.start();
      gateway.emit(const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.purchased));
      await Future<void>.delayed(Duration.zero);

      rows = await database.notificationDao.getRowsForRenewal(id);
      final pending = rows.where((r) => r.status == 'pending').toList();
      expect(pending, hasLength(3), reason: 'Vehicle: full 30/14/3-day paid ladder, all still ahead of "now"');
    },
  );

  test('an update for a different product id is ignored (this app has exactly one SKU)', () async {
    await manager.start();

    gateway.emit(const PurchaseUpdateRecord(productId: 'some_other_sku', kind: PurchaseResultKind.purchased));
    await Future<void>.delayed(Duration.zero);

    expect(await entitlementRepository.isEntitled(), isFalse);
  });
}
