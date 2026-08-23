import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/database/app_database.dart';
import '../../data/repository/renewal_repository.dart';
import 'notification_action_handler.dart';
import 'notification_action_ids.dart';
import 'notification_service.dart';
import 'reconciliation_service.dart';

/// Entry point Android launches in a fresh background isolate — no live
/// Flutter engine, no app widget tree, none of whatever `main()` already
/// constructed — when a notification action is tapped and the app process
/// isn't running (task brief item 5: "handled when the app is backgrounded
/// or not running"). Must be top-level (or static) and annotated
/// `@pragma('vm:entry-point')`, or a release build's tree-shaker can strip
/// it as apparently-unused, and this silently never fires — a real,
/// easy-to-miss first-build failure mode, flagged in the developer
/// handoff.
///
/// **Unverifiable in this environment**: whether `path_provider` (which
/// `AppDatabase` depends on to locate the sqlite file) and
/// `flutter_local_notifications` actually behave correctly inside this
/// specific background-isolate context on a real device has not been
/// confirmed — no SDK/device/emulator exists here to run it against. This
/// follows both plugins' documented pattern for background isolates, but
/// is one of the riskiest, least-verified pieces of this slice.
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  if (response.actionId != NotificationActionIds.markDone) return;
  final renewalId = int.tryParse(response.payload ?? '');
  if (renewalId == null) return;

  // Fire-and-forget by necessity: this callback itself is synchronous
  // (`void`, not `Future<void>`), so the async work below is kicked off but
  // not awaited here. flutter_local_notifications' documented contract is
  // that the OS keeps this isolate alive long enough for in-flight
  // plugin/platform-channel work triggered from within the callback to
  // complete — a real, load-bearing assumption this environment cannot
  // verify without a device.
  _run(renewalId);
}

Future<void> _run(int renewalId) async {
  final database = AppDatabase();
  try {
    final renewalRepository = RenewalRepository(database.renewalDao);
    final notificationService = NotificationService();
    // No `onMarkDoneWhileAlive` callback here — this isolate has no live
    // app instance for one to call back into; the work happens directly
    // below via `NotificationActionHandler`, not through that hook.
    await notificationService.init();
    final reconciliationService = ReconciliationService(
      renewalRepository: renewalRepository,
      notificationDao: database.notificationDao,
      notificationService: notificationService,
    );
    await NotificationActionHandler.handleMarkDone(
      renewalId: renewalId,
      renewalRepository: renewalRepository,
      notificationDao: database.notificationDao,
      notificationService: notificationService,
      reconciliationService: reconciliationService,
    );
  } finally {
    await database.close();
  }
}
