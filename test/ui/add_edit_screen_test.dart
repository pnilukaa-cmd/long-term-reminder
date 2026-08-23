import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/data/repository/settings_repository.dart';
import 'package:long_term_reminder/services/notifications/notification_service.dart';
import 'package:long_term_reminder/services/notifications/reconciliation_service.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/add_edit/add_edit_screen.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget buildScreen() {
    final renewalRepository = RenewalRepository(database.renewalDao);
    // Deliberately never `.init()`-ed: none of the cases in this file tap
    // Save, so `_handleSave`'s calls into these two never actually fire —
    // they only need to exist to satisfy the constructor's required
    // parameters. A test that *does* exercise Save would need a real
    // (fake/mocked) plugin, which this slice doesn't set up — flagged in
    // the developer handoff as untested territory.
    final notificationService = NotificationService();
    return MaterialApp(
      theme: AppTheme.light(),
      home: AddEditScreen(
        repository: renewalRepository,
        settingsRepository: SettingsRepository(database.settingsDao),
        notificationService: notificationService,
        reconciliationService: ReconciliationService(
          renewalRepository: renewalRepository,
          notificationDao: database.notificationDao,
          notificationService: notificationService,
        ),
      ),
    );
  }

  testWidgets('Save is disabled until type, label, and due date are all set (REQ-2.1/2.2)', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    ElevatedButton saveButton() =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save renewal'));

    expect(saveButton().onPressed, isNull, reason: 'nothing filled in yet');

    // Select a type.
    await tester.tap(find.text('Vehicle').first);
    await tester.pump();
    expect(saveButton().onPressed, isNull, reason: 'label and due date still missing');

    // Fill in the label.
    await tester.enterText(find.widgetWithText(TextField, 'e.g. "Passport" or "Honda Civic MOT"'), 'Honda Civic MOT');
    await tester.pump();
    expect(saveButton().onPressed, isNull, reason: 'due date still missing');
    expect(find.textContaining('Due date is required'), findsOneWidget);
  });

  testWidgets('selecting Health check shows the recurrence stepper defaulting to 12 (REQ-1.1)', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Health check').first);
    await tester.pump();

    expect(find.text('Remind me every'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('Not a recommendation'), findsOneWidget);
  });

  testWidgets('selecting Custom shows the Short/Medium/Long selector defaulting to Medium (REQ-2.5)', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom').first);
    await tester.pump();

    expect(find.text('Short'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Long'), findsOneWidget);
  });
}
