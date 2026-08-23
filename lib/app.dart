import 'dart:async';

import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repository/entitlement_repository.dart';
import 'data/repository/renewal_repository.dart';
import 'data/repository/settings_repository.dart';
import 'services/billing/billing_gateway.dart';
import 'services/billing/play_billing_gateway.dart';
import 'services/billing/purchase_manager.dart';
import 'services/notifications/notification_action_handler.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/reconciliation_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

/// Root widget. Owns the single [AppDatabase] instance and the repositories
/// built on top of it — everything below this widget reaches storage only
/// through [RenewalRepository]/[SettingsRepository]/[EntitlementRepository]/
/// [NotificationDao], never the raw database directly. Also owns the
/// [ReconciliationService] wiring
/// (docs/technical/04-scheduling-and-stack.md §2): the live-process
/// `Mark done` notification-action handler, the launch/foreground
/// reconciliation pass, and (this slice) the [BillingGateway]/
/// [PurchaseManager] wiring — the app-lifetime purchase-stream subscription
/// that turns a purchase/restore into a persisted entitlement change plus
/// a rescheduling pass, wherever it happened (paywall, Settings, or a
/// [PurchaseResultKind.pending] purchase clearing on its own later).
class RenewalReminderApp extends StatefulWidget {
  const RenewalReminderApp({super.key, required this.notificationService});

  /// Constructed and `init()`-ed in `main()`, before `runApp` — see that
  /// file and [NotificationService.onMarkDoneWhileAlive]'s doc comment for
  /// why it's threaded in rather than constructed here.
  final NotificationService notificationService;

  @override
  State<RenewalReminderApp> createState() => _RenewalReminderAppState();
}

class _RenewalReminderAppState extends State<RenewalReminderApp> {
  late final AppDatabase _database = AppDatabase();
  late final RenewalRepository _renewalRepository = RenewalRepository(_database.renewalDao);
  late final SettingsRepository _settingsRepository = SettingsRepository(_database.settingsDao);
  late final EntitlementRepository _entitlementRepository = EntitlementRepository(_database.settingsDao);

  /// The real [PlayBillingGateway] — **unverified**, see that class's own
  /// doc comment. Everything downstream of it (gating, scheduling) is
  /// built and tested against [BillingGateway]'s interface, not this
  /// specific implementation, per the developer task brief.
  late final BillingGateway _billingGateway = PlayBillingGateway();

  late final ReconciliationService _reconciliationService = ReconciliationService(
    renewalRepository: _renewalRepository,
    notificationDao: _database.notificationDao,
    notificationService: widget.notificationService,
    entitlementRepository: _entitlementRepository,
  );

  late final PurchaseManager _purchaseManager = PurchaseManager(
    billingGateway: _billingGateway,
    entitlementRepository: _entitlementRepository,
    reconciliationService: _reconciliationService,
  );

  @override
  void initState() {
    super.initState();
    widget.notificationService.onMarkDoneWhileAlive = _handleMarkDoneWhileAlive;

    // Subscribes for the app's lifetime (see [PurchaseManager]'s class
    // doc on why this must not be scoped to the paywall screen alone).
    // Fire-and-forget for the same reason as the reconciliation call
    // below — nothing in the first frame depends on this having completed.
    unawaited(_billingGateway.init().then((_) => _purchaseManager.start()));

    // docs/technical/04-scheduling-and-stack.md §2: reconciliation runs "on
    // every app launch/foreground" — this is that trigger. Deliberately
    // fire-and-forget from `initState` (not awaited before the first
    // frame): the list screen's own stream-driven loading state already
    // covers the interval before this completes, and blocking startup on a
    // full reconcile pass would be a real, avoidable jank cost for
    // something the periodic task will also catch within 24h regardless.
    unawaited(_reconciliationService.reconcile());
  }

  Future<void> _handleMarkDoneWhileAlive(int renewalId) {
    return NotificationActionHandler.handleMarkDone(
      renewalId: renewalId,
      renewalRepository: _renewalRepository,
      notificationDao: _database.notificationDao,
      notificationService: widget.notificationService,
      reconciliationService: _reconciliationService,
    );
  }

  @override
  void dispose() {
    _purchaseManager.dispose();
    _billingGateway.dispose();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Renewal Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(
        repository: _renewalRepository,
        settingsRepository: _settingsRepository,
        entitlementRepository: _entitlementRepository,
        billingGateway: _billingGateway,
        notificationService: widget.notificationService,
        notificationDao: _database.notificationDao,
        reconciliationService: _reconciliationService,
      ),
    );
  }
}
