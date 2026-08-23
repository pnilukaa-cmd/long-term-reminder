import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/settings/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Covers REQ-15.1's three states plus the two required-before-ship legal
/// surfaces (REQ-1.4's disclaimer, REQ-15.2's privacy card) and the
/// notification-permission recovery affordance (REQ-11.1). Deliberately
/// does **not** exercise the real `permission_handler` platform channel —
/// there's no plugin registered in the widget-test harness (and no
/// device/emulator in this environment to verify real plugin behavior
/// against either) — [SettingsScreen.checkNotificationPermission] exists
/// specifically so this file can inject a fake instead of depending on
/// unverified platform-channel mocking. Same reasoning already used by
/// `add_edit_screen_test.dart` for `NotificationService`.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget buildScreen({required Future<ph.PermissionStatus> Function() checker}) {
    final renewalRepository = RenewalRepository(database.renewalDao);
    final notificationService = NotificationService();
    final reconciliationService = ReconciliationService(
      renewalRepository: renewalRepository,
      notificationDao: database.notificationDao,
      notificationService: notificationService,
    );
    return MaterialApp(
      theme: AppTheme.light(),
      home: SettingsScreen(
        notificationDao: database.notificationDao,
        notificationService: notificationService,
        reconciliationService: reconciliationService,
        checkNotificationPermission: checker,
      ),
    );
  }

  testWidgets('granted permission shows the "On" status (REQ-15.1 success state)', (tester) async {
    await tester.pumpWidget(buildScreen(checker: () async => ph.PermissionStatus.granted));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.textContaining('On — manage in system settings'), findsOneWidget);
  });

  testWidgets('denied permission shows a recovery-oriented status, and the tile still routes to system settings '
      '(REQ-11.1)', (tester) async {
    await tester.pumpWidget(buildScreen(checker: () async => ph.PermissionStatus.denied));
    await tester.pumpAndSettle();

    expect(find.textContaining('Off — tap to turn it back on'), findsOneWidget);
    // The tile itself is the recovery route (opens system settings on
    // tap) — just confirm it's present; the actual OS deep-link
    // (`permission_handler`'s `openAppSettings()`) isn't invokable in this
    // harness (see file doc comment), so tapping it isn't exercised here.
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('a failed permission check shows the error state with a working retry (REQ-15.1)', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      buildScreen(
        checker: () async {
          attempts++;
          if (attempts == 1) throw Exception('simulated platform-channel failure');
          return ph.PermissionStatus.granted;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load settings"), findsOneWidget);
    expect(find.textContaining("doesn't hold your renewal data"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load settings"), findsNothing);
    expect(find.textContaining('On — manage in system settings'), findsOneWidget);
  });

  testWidgets('the full REQ-1.4 disclaimer renders, including the force-stop paragraph', (tester) async {
    await tester.pumpWidget(buildScreen(checker: () async => ph.PermissionStatus.granted));
    await tester.pumpAndSettle();

    expect(find.text('Not legal, financial, or medical advice'), findsOneWidget);
    expect(
      find.textContaining('Android cancels every reminder that was waiting to fire'),
      findsOneWidget,
      reason: 'REQ-1.4\'s 2026-08-23 strengthening — must name the mechanism plainly, not "may be delayed."',
    );
    expect(find.textContaining("you're still responsible for the renewal"), findsOneWidget);
  });

  testWidgets('the privacy card states the local-only guarantee with the Play Billing scoped exception '
      '(REQ-15.2)', (tester) async {
    await tester.pumpWidget(buildScreen(checker: () async => ph.PermissionStatus.granted));
    await tester.pumpAndSettle();

    expect(find.text('Everything stays on this device'), findsOneWidget);
    expect(find.textContaining('purchase check with Google Play'), findsOneWidget);
  });

  testWidgets('the debug scheduled-state entry point is present (moved here from the home app bar)', (tester) async {
    await tester.pumpWidget(buildScreen(checker: () async => ph.PermissionStatus.granted));
    await tester.pumpAndSettle();

    // `flutter test` runs in debug mode, so `kDebugMode` is true here —
    // this exercises the same gate a real debug build would.
    expect(find.text('Scheduled state (debug)'), findsOneWidget);
  });
}
