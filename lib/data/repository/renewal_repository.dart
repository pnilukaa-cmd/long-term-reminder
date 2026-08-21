import 'package:drift/drift.dart';

import '../../domain/models/custom_tier.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_type.dart';
import '../database/app_database.dart';
import '../database/renewal_dao.dart';

/// Domain-facing wrapper over [RenewalDao]. This is the only place that
/// translates between drift's generated row/companion classes (persisted
/// as plain strings for enums) and the app's [Renewal] domain model, so
/// `lib/domain/` stays free of any drift dependency.
class RenewalRepository {
  RenewalRepository(this._dao);

  final RenewalDao _dao;

  Stream<List<Renewal>> watchAll() {
    return _dao.watchAllItems().map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  Future<Renewal?> getById(int id) async {
    final row = await _dao.getItemById(id);
    return row == null ? null : _toDomain(row);
  }

  Future<int> createItem({
    required RenewalType type,
    required String label,
    required DateTime dueDate,
    String? notes,
    CustomTier? customTier,
    int? healthRecurrenceMonths,
  }) {
    final now = DateTime.now();
    return _dao.insertItem(
      RenewalItemsCompanion.insert(
        type: type.name,
        label: label,
        dueDate: dueDate,
        notes: Value(notes),
        customTier: Value(customTier?.name),
        healthRecurrenceMonths: Value(healthRecurrenceMonths),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Edits an existing item. Per REQ-16.1, changing the due date or type
  /// is functionally the same operation (full ladder recompute) — this
  /// slice doesn't own scheduling, so there's no cancel/reschedule side
  /// effect to trigger yet, but the write itself is unconditional and
  /// always up to date with whatever the form submitted.
  ///
  /// Every column is passed explicitly (including [createdAt], sourced
  /// from the original row) rather than leaning on `.replace()`'s
  /// absent-field behaviour to preserve it implicitly — cheap insurance
  /// against a subtle, hard-to-notice data bug in exactly the kind of
  /// write this project can't afford to get wrong silently.
  Future<void> updateItem({
    required int id,
    required RenewalType type,
    required String label,
    required DateTime dueDate,
    String? notes,
    CustomTier? customTier,
    int? healthRecurrenceMonths,
    required bool isDone,
    DateTime? lastCompletedAt,
    required DateTime createdAt,
  }) {
    return _dao.updateItem(
      RenewalItemsCompanion(
        id: Value(id),
        type: Value(type.name),
        label: Value(label),
        dueDate: Value(dueDate),
        notes: Value(notes),
        customTier: Value(customTier?.name),
        healthRecurrenceMonths: Value(healthRecurrenceMonths),
        isDone: Value(isDone),
        lastCompletedAt: Value(lastCompletedAt),
        createdAt: Value(createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Actually removes the row. Callers (the undo controller) are
  /// responsible for only calling this once the 6-second undo window has
  /// lapsed (REQ-10.2) — this method itself has no notion of "pending".
  Future<void> deleteItem(int id) => _dao.deleteItemById(id);

  /// Actually commits a mark-done action. Same "only call once the undo
  /// window has lapsed" contract as [deleteItem].
  Future<void> commitMarkDone(int id, {DateTime? nextDueDate}) {
    return _dao.markDone(id, completedAt: DateTime.now(), nextDueDate: nextDueDate);
  }

  Renewal _toDomain(RenewalItem row) {
    return Renewal(
      id: row.id,
      type: RenewalType.fromName(row.type),
      label: row.label,
      dueDate: row.dueDate,
      notes: row.notes,
      customTier: row.customTier == null ? null : CustomTier.fromName(row.customTier!),
      healthRecurrenceMonths: row.healthRecurrenceMonths,
      isDone: row.isDone,
      lastCompletedAt: row.lastCompletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
