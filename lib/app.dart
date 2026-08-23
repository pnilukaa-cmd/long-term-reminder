import 'dart:async';

import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repository/renewal_repository.dart';
import 'data/repository/settings_repository.dart';
import 'services/notifications/notification_action_handler.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/reconciliation_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

/// Root widget. Owns the single [AppDatabase] instance and the repositories
/// built on top of it — everything below this widget reaches storage only
/// through [RenewalRepository]/[SettingsRepository]/[NotificationDao],
/// never the raw database directly. Also owns the [ReconciliationService]
/// wiring (docs/technical/04-scheduling-and-stack.md §2): the live-process
/// `Mark done` notification-action handler, and the launch/foreground
/// reconciliation pass.
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
  late final ReconciliationService _reconciliationService = ReconciliationService(
    renewalRepository: _renewalRepository,
    notificationDao: _database.notificationDao,
    notificationService: widget.notificationService,
  );

  @override
  void initState() {
    super.initState();
    widget.notificationService.onMarkDoneWhileAlive = _handleMarkDoneWhileAlive;

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
        notificationService: widget.notificationService,
        notificationDao: _database.notificationDao,
        reconciliationService: _reconciliationService,
      ),
    );
  }
}
