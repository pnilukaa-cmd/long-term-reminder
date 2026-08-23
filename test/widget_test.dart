// Smoke test for the real app shell: boots against an in-memory database
// (no filesystem access, no path_provider plugin channel needed) and
// checks that a brand-new install renders the first-run empty state
// (REQ-4.1) rather than a blank screen or an unhandled exception.
//
// NOTE TO WHOEVER RUNS THIS: this test constructs `AppDatabase.forTesting`
// with an in-memory `NativeDatabase`, which needs the generated
// `app_database.g.dart` (via `dart run build_runner build`) to exist
// before this file will even compile. See the developer handoff notes in
// the PR/commit message for the full command sequence.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/data/repository/settings_repository.dart';
import 'package:long_term_reminder/services/billing/fake_billing_gateway.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/home/home_screen.dart';

void main() {
  testWidgets('fresh install shows the first-run empty state, not a blank screen', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final renewalRepository = RenewalRepository(database.renewalDao);
    final settingsRepository = SettingsRepository(database.settingsDao);
    final entitlementRepository = EntitlementRepository(database.settingsDao);
    // Never `.init()`-ed — this smoke test never triggers a save/delete/
    // mark-done, so these are only here to satisfy required constructor
    // parameters, same rationale as add_edit_screen_test.dart.
    final notificationService = NotificationService();
    final reconciliationService = ReconciliationService(
      renewalRepository: renewalRepository,
      notificationDao: database.notificationDao,
      notificationService: notificationService,
      entitlementRepository: entitlementRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          repository: renewalRepository,
          settingsRepository: settingsRepository,
          entitlementRepository: entitlementRepository,
          billingGateway: FakeBillingGateway(),
          notificationService: notificationService,
          notificationDao: database.notificationDao,
          reconciliationService: reconciliationService,
        ),
      ),
    );

    // First frame: the stream hasn't emitted yet — loading skeleton.
    await tester.pump();

    // Let the drift stream deliver its first (empty) snapshot.
    await tester.pumpAndSettle();

    expect(find.text('What do you want to track first?'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('Health check'), findsOneWidget);
  });
}
