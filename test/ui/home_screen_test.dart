import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/data/repository/settings_repository.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/home/home_screen.dart';

/// Developer task brief item 6: "the home app bar should not carry
/// developer affordances." Deliberately does not assert on what
/// `SettingsScreen` itself renders once pushed (it does its own real
/// `permission_handler` platform-channel check, unmocked here — see
/// `settings_screen_test.dart`, which exercises that screen directly via
/// its injectable checker instead) — only that the debug icon is gone from
/// this app bar and that the gear icon now navigates rather than showing
/// the old "not built yet" SnackBar.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget buildScreen() {
    final renewalRepository = RenewalRepository(database.renewalDao);
    final notificationService = NotificationService();
    return MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
        repository: renewalRepository,
        settingsRepository: SettingsRepository(database.settingsDao),
        notificationService: notificationService,
        notificationDao: database.notificationDao,
        reconciliationService: ReconciliationService(
          renewalRepository: renewalRepository,
          notificationDao: database.notificationDao,
          notificationService: notificationService,
        ),
      ),
    );
  }

  testWidgets('the home app bar carries no debug affordance and only a Settings gear', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('tapping the Settings gear navigates away from Home (no more "not built yet" SnackBar)', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    // Deliberately bounded pumps, not `pumpAndSettle()`: `SettingsScreen`'s
    // real (unmocked in this file — see `settings_screen_test.dart` for
    // the properly-injected version) `permission_handler` platform-channel
    // check is what the loading skeleton is waiting on, and that
    // skeleton's shimmer is a repeating `AnimationController` — exactly
    // the kind of persistent-animation source `pumpAndSettle()` isn't
    // built to wait out. A couple of bounded pumps is enough to carry the
    // push transition through; this test only needs to prove navigation
    // happened, not that `SettingsScreen` finished loading.
    await tester.pump();
    // Exceeds `MaterialPageRoute`'s default ~300ms transition duration, so
    // Home's route has actually finished being pushed off-screen (and
    // isn't just mid-transition, which would leave its widgets briefly
    // still present) — still a single bounded pump, not a `pumpAndSettle`
    // loop that could get stuck on the destination screen's shimmer.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("Settings isn't built yet — coming in a later slice."), findsNothing);
    expect(find.text('Your renewals'), findsNothing, reason: 'Home app bar title should no longer be on screen');
  });
}
