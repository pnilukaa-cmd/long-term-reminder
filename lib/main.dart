import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/workmanager_dispatcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Constructed once here rather than inside `RenewalReminderApp` so its
  // `init()` (channel + timezone setup) has definitely completed before the
  // very first build, and so the same instance is what both the live
  // notification-response callback and `app.dart`'s launch-time
  // reconciliation pass use. `onMarkDoneWhileAlive` is wired later, in
  // `app.dart`'s `initState` — see that field's own doc comment for why.
  final notificationService = NotificationService();
  await notificationService.init();

  // Task brief item 2 — the periodic half of the self-healing
  // reconciliation pass (docs/technical/04-scheduling-and-stack.md §2).
  // `initialize` + `registerPeriodicTask` are both idempotent per
  // `workmanager`'s own documented contract (re-registering with the same
  // unique name and `ExistingPeriodicWorkPolicy.keep` is a safe no-op on
  // every subsequent app launch, not a duplicate task).
  Workmanager().initialize(callbackDispatcher);
  await registerPeriodicReconciliation();

  runApp(RenewalReminderApp(notificationService: notificationService));
}
