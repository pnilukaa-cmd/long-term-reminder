import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/database/app_database.dart';
import '../../data/repository/entitlement_repository.dart';
import '../../data/repository/renewal_repository.dart';
import 'notification_service.dart';
import 'reconciliation_service.dart';

/// Task brief item 2 — the periodic background half of the self-healing
/// reconciliation pass named in
/// docs/technical/04-scheduling-and-stack.md §2. The other half (on every
/// app launch/foreground) is wired directly in `app.dart`'s `initState`.
const String reconciliationTaskName = 'com.pnilukaa.long_term_reminder.reconciliation';

/// Registered once from `main()`. `workmanager`'s own documented contract
/// (per the scheduling ADR §2) is that a `PeriodicWorkRequest` persists to
/// WorkManager's internal database and re-arms itself after reboot without
/// this app needing its own `BOOT_COMPLETED` receiver for *this* purpose —
/// the manifest boot receiver this slice also adds
/// (`AndroidManifest.xml`) is for `flutter_local_notifications`'
/// already-scheduled alarms specifically, a separate, complementary
/// mechanism, not a duplicate of this one. 24h is well above Android's
/// 15-minute floor for periodic work; there's no reason to push that
/// limit for a once-a-day reconciliation pass.
Future<void> registerPeriodicReconciliation() {
  return Workmanager().registerPeriodicTask(
    reconciliationTaskName,
    reconciliationTaskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}

/// Top-level, `@pragma('vm:entry-point')`-annotated dispatcher `workmanager`
/// launches in its own background isolate to run any registered task —
/// same isolate-isolation caveats as
/// `notification_background_handler.dart`'s doc comment (path_provider /
/// plugin behaviour in a background isolate is unverified in this
/// environment). Handles only [reconciliationTaskName]; a `switch` on
/// `task` is future-proofing for if a second background task is ever added,
/// not evidence one exists today.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != reconciliationTaskName) return true;

    final database = AppDatabase();
    try {
      final renewalRepository = RenewalRepository(database.renewalDao);
      final entitlementRepository = EntitlementRepository(database.settingsDao);
      final notificationService = NotificationService();
      await notificationService.init();
      final reconciliationService = ReconciliationService(
        renewalRepository: renewalRepository,
        notificationDao: database.notificationDao,
        notificationService: notificationService,
        entitlementRepository: entitlementRepository,
      );
      await reconciliationService.reconcile();
      return true;
    } catch (_) {
      // `workmanager`'s contract for a `false` return is "retry with
      // backoff" — appropriate here, since a transient failure (e.g. the
      // sqlite file briefly locked by the foreground app) should retry
      // rather than silently give up on a whole day's reconciliation pass.
      return false;
    } finally {
      await database.close();
    }
  });
}
