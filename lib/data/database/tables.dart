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

  /// REQ-9.5 / design doc §4's deferred recurrence decision, and the
  /// developer task brief's "close the recurring mark-done gap": true
  /// when a `Mark done` notification action on a *recurring* type has
  /// already cancelled this cycle's remaining nags but the "when's it
  /// next due?" question hasn't been answered yet (no foreground UI
  /// existed at the moment the notification fired, per REQ-9.5). Item
  /// detail surfaces this as an inline banner — never a second
  /// notification — the next time it's opened; resolving it (via the same
  /// recurrence flow every other mark-done uses) or manually editing the
  /// item (which supersedes the deferred question) clears the flag.
  ///
  /// [ReconciliationPlanner] must treat this exactly like `isDone` — see
  /// its class doc — or the very next reconciliation pass (which
  /// `NotificationActionHandler` itself triggers right after setting this
  /// flag) would recompute the same due-date-driven stages and silently
  /// re-arm the ones that were just cancelled.
  BoolColumn get pendingRecurrenceDecision => boolean().withDefault(const Constant(false))();

  /// `Undo last completion` (scope doc §3d) — single-level undo of the
  /// most recent mark-done *commit*, for a mistake noticed after the
  /// 6-second undo toast has already expired. True iff the most recent
  /// thing that happened to this item was a completed mark-done and
  /// nothing has touched it since — another edit, another mark-done, or a
  /// prior use of this same action all clear it (see [RenewalDao]).
  BoolColumn get hasUndoableCompletion => boolean().withDefault(const Constant(false))();

  /// Snapshot of `dueDate` immediately before the most recent mark-done
  /// commit — only meaningful when [hasUndoableCompletion] is true; what
  /// `Undo last completion` restores.
  DateTimeColumn get preCompletionDueDate => dateTime().nullable()();

  /// Snapshot of `lastCompletedAt` immediately before the most recent
  /// mark-done commit — only meaningful when [hasUndoableCompletion] is
  /// true. May itself legitimately be null (this being the item's very
  /// first-ever completion).
  DateTimeColumn get preCompletionLastCompletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// A small generic key/value table for one-time, per-install flags — e.g.
/// the Health check "Got it" note dismissal (REQ-1.2), and (this slice)
/// the "notification permission already primed" flag. Kept in the same
/// drift database rather than introducing `shared_preferences` as a second
/// storage mechanism, per docs/technical/04-scheduling-and-stack.md §4.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The reliability model's actual source of truth, per
/// docs/technical/04-scheduling-and-stack.md §2: "Source of truth lives in
/// the local database, not in the OS alarm table." One row per notification
/// occurrence this app has ever decided *should* exist for an item — the
/// reconciliation pass (`lib/services/notifications/reconciliation_service.dart`)
/// diffs [ReconciliationPlanner]'s freshly-computed desired set against
/// these rows on every app launch/foreground and via a periodic
/// `workmanager` task, and re-arms or cancels to match. A previously-made
/// scheduling call is never trusted to have survived on its own — this
/// table, not the OS alarm table, is what's asked "what should be
/// scheduled right now."
///
/// This row's own autoincrement `id` **is** the Android notification ID
/// passed to `flutter_local_notifications` — there's no separate
/// `androidNotificationId` column, since the row id already is a stable,
/// unique, small integer the moment it's inserted; introducing a second
/// column for the same value would just be a second source of truth for
/// no benefit.
@DataClassName('ScheduledNotification')
class ScheduledNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK-by-convention to `RenewalItems.id` (drift's `references()` isn't
  /// used here so a deleted item's rows can be cleaned up explicitly by
  /// the reconciliation pass rather than relying on cascade behaviour —
  /// see [NotificationDao.deleteForRenewal]).
  IntColumn get renewalId => integer()();

  /// `NotificationKind.name` — "ladderStage" or "overdueNag".
  TextColumn get kind => text()();

  /// [DesiredNotification.stageKey] — this row's stable identity across
  /// reconciliation runs, independent of its date (e.g. "ladder:2",
  /// "overdue:0"). See that class's doc comment for the full diffing
  /// contract this enables.
  TextColumn get stageKey => text()();

  /// The calendar day (local midnight) this is scheduled to fire on.
  DateTimeColumn get fireOn => dateTime()();

  /// REQ-12.1's grouping key — the ISO date string notifications sharing
  /// a calendar day group under.
  TextColumn get groupDateKey => text()();

  /// [ScheduledNotificationStatus.name] — pending / fired / cancelled /
  /// skipped. See that enum's doc comment for the state machine.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
