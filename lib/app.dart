import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repository/renewal_repository.dart';
import 'data/repository/settings_repository.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

/// Root widget. Owns the single [AppDatabase] instance and the two thin
/// repositories built on top of it — everything below this widget reaches
/// storage only through [RenewalRepository]/[SettingsRepository], never
/// the DAOs or database directly.
class RenewalReminderApp extends StatefulWidget {
  const RenewalReminderApp({super.key});

  @override
  State<RenewalReminderApp> createState() => _RenewalReminderAppState();
}

class _RenewalReminderAppState extends State<RenewalReminderApp> {
  late final AppDatabase _database = AppDatabase();
  late final RenewalRepository _renewalRepository = RenewalRepository(_database.renewalDao);
  late final SettingsRepository _settingsRepository = SettingsRepository(_database.settingsDao);

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
      ),
    );
  }
}
