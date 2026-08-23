// REQ-3.2/REQ-5.2 — item detail's free/paid ladder-track gating, this
// slice's real integration point for the paywall. Exercises the whole
// screen against a real in-memory database and FakeBillingGateway.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/data/repository/settings_repository.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/services/billing/fake_billing_gateway.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/detail/item_detail_screen.dart';

void main() {
  late AppDatabase database;
  late RenewalRepository repository;
  late EntitlementRepository entitlementRepository;
  late int itemId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RenewalRepository(database.renewalDao);
    entitlementRepository = EntitlementRepository(database.settingsDao);
    itemId = await repository.createItem(
      type: RenewalType.vehicle,
      label: 'Honda Civic MOT',
      dueDate: DateTime.now().add(const Duration(days: 90)),
    );
  });

  tearDown(() => database.close());

  Widget buildScreen() {
    final notificationService = NotificationService();
    return MaterialApp(
      theme: AppTheme.light(),
      home: ItemDetailScreen(
        itemId: itemId,
        repository: repository,
        settingsRepository: SettingsRepository(database.settingsDao),
        entitlementRepository: entitlementRepository,
        billingGateway: FakeBillingGateway(),
        notificationService: notificationService,
        reconciliationService: ReconciliationService(
          renewalRepository: repository,
          notificationDao: database.notificationDao,
          notificationService: notificationService,
          entitlementRepository: entitlementRepository,
        ),
      ),
    );
  }

  testWidgets('free tier (default, not entitled) shows the free-plan header and an unlock banner', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Your reminder (free plan)'), findsOneWidget);
    expect(find.textContaining('more warning'), findsOneWidget);
    expect(find.textContaining('Unlock'), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsWidgets, reason: 'locked stage markers on the track');
  });

  testWidgets('entitled item shows the full ladder header and no unlock banner', (tester) async {
    await entitlementRepository.setEntitled(true);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Your reminder ladder'), findsOneWidget);
    expect(find.textContaining('more warning'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.textContaining('Full ladder active'), findsOneWidget);
  });

  testWidgets('tapping the unlock banner opens the paywall screen', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Unlock —').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Unlock the full ladder'), findsOneWidget);
  });

  testWidgets('a purchase completing while this screen is open updates the track live, no navigation needed', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Your reminder (free plan)'), findsOneWidget);

    await entitlementRepository.setEntitled(true);
    await tester.pumpAndSettle();

    expect(find.text('Your reminder ladder'), findsOneWidget);
    expect(find.text('Your reminder (free plan)'), findsNothing);
  });
}
