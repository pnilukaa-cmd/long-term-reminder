import 'package:drift/drift.dart';

/// Renewal items — one row per tracked renewal. Covers all seven preset
/// types, due date, label, notes, the Custom short/medium/long lead-time
/// selection, the Health check recurrence-in-months setting, and
/// done/completed state, per the developer task brief.
///
/// `type` and `customTier` store the corresponding enum's `.name` — see
/// `lib/domain/models/renewal_type.dart` / `custom_tier.dart`. Storing the
/// enum name (not its index) means adding a new type later doesn't shift
/// the meaning of existing rows.
@DataClassName('RenewalItem')
class RenewalItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// RenewalType.name — e.g. "passport", "healthCheck".
  TextColumn get type => text()();

  TextColumn get label => text()();

  DateTimeColumn get dueDate => dateTime()();

  TextColumn get notes => text().nullable()();

  /// CustomTier.name — only meaningful when type == "custom".
  TextColumn get customTier => text().nullable()();

  /// Recurrence interval in months — only meaningful when
  /// type == "healthCheck". Defaults to 12 per REQ-1.1.
  IntColumn get healthRecurrenceMonths => integer().nullable()();

  /// Whether the item's current cycle has been marked done (REQ-4.2).
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// When the item was last marked done, if ever. Used for the Done
  /// card's "Renewed [date]" line.
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// A small generic key/value table for one-time, per-install flags — e.g.
/// the Health check "Got it" note dismissal (REQ-1.2). Kept in the same
/// drift database rather than introducing `shared_preferences` as a second
/// storage mechanism, per docs/technical/04-scheduling-and-stack.md §4.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
