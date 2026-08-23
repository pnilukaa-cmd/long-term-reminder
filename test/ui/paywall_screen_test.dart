// REQ-14 — the paywall screen's four mocked states plus the extra ones the
// developer task brief names. Exercised against FakeBillingGateway and an
// in-memory database.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/services/billing/billing_gateway.dart';
import 'package:long_term_reminder/services/billing/fake_billing_gateway.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/paywall/paywall_screen.dart';

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

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: PaywallScreen(
        billingGateway: gateway,
        entitlementRepository: entitlementRepository,
        reconciliationService: reconciliationService,
      ),
    );
  }

  testWidgets('default state shows the comparison list, live price, and both actions', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Unlock the full ladder'), findsOneWidget);
    expect(find.text('Unlock for \$3.99'), findsOneWidget);
    expect(find.text('Restore purchase'), findsOneWidget);
    expect(find.text('Full multi-stage ladder'), findsOneWidget);
  });

  testWidgets('tapping Unlock and a successful purchase shows the success state (REQ-14.1)', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    gateway.nextBuyOutcome = const PurchaseUpdateRecord(productId: kUnlockProductId, kind: PurchaseResultKind.purchased);
    await tester.tap(find.text('Unlock for \$3.99'));
    await tester.pumpAndSettle();

    expect(find.text("You're set"), findsOneWidget);
    expect(await entitlementRepository.isEntitled(), isFalse, reason: 'granting entitlement is PurchaseManager\'s job, not this screen\'s — no PurchaseManager is wired in this test');
  });

  testWidgets('a purchase error shows the error state with reassurance copy, not silence', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    gateway.nextBuyOutcome = const PurchaseUpdateRecord(
      productId: kUnlockProductId,
      kind: PurchaseResultKind.error,
      errorMessage: "Purchase didn't go through — you haven't been charged. Check your connection and try again.",
    );
    await tester.tap(find.text('Unlock for \$3.99'));
    await tester.pumpAndSettle();

    expect(find.textContaining("haven't been charged"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Restore purchase'), findsOneWidget);
  });

  testWidgets('billing unavailable shows a distinct, non-alarming state with a retry', (tester) async {
    gateway.available = false;
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text("You're set"), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining("aren't available"), findsOneWidget);
  });

  testWidgets('already-entitled install opens straight to the success state', (tester) async {
    await entitlementRepository.setEntitled(true);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text("You're already unlocked"), findsOneWidget);
  });
}
