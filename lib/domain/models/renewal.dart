import 'custom_tier.dart';
import 'renewal_type.dart';

/// A tracked renewal item, in domain terms — deliberately independent of
/// drift's generated row class (`RenewalItem` in
/// `lib/data/database/tables.dart`) so `lib/domain/` has no dependency on
/// the persistence layer and stays trivially unit testable. The
/// repository is the only place that translates between the two.
class Renewal {
  const Renewal({
    required this.id,
    required this.type,
    required this.label,
    required this.dueDate,
    this.notes,
    this.customTier,
    this.healthRecurrenceMonths,
    required this.isDone,
    this.lastCompletedAt,
    this.pendingRecurrenceDecision = false,
    this.hasUndoableCompletion = false,
    this.preCompletionDueDate,
    this.preCompletionLastCompletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final RenewalType type;
  final String label;
  final DateTime dueDate;
  final String? notes;

  /// Only meaningful when `type == RenewalType.custom`.
  final CustomTier? customTier;

  /// Only meaningful when `type == RenewalType.healthCheck`.
  final int? healthRecurrenceMonths;

  final bool isDone;
  final DateTime? lastCompletedAt;

  /// REQ-9.5's deferred recurrence decision — see
  /// `lib/data/database/tables.dart`'s doc comment on the underlying
  /// column for the full contract. Drives item detail's inline banner.
  final bool pendingRecurrenceDecision;

  /// `Undo last completion` (scope doc §3d) — true iff the most recent
  /// thing that happened to this item was a completed mark-done and
  /// nothing has touched it since. Drives item detail's overflow-menu
  /// entry.
  final bool hasUndoableCompletion;

  /// Snapshot restored by `Undo last completion` — only meaningful when
  /// [hasUndoableCompletion] is true.
  final DateTime? preCompletionDueDate;

  /// Snapshot restored by `Undo last completion` — only meaningful when
  /// [hasUndoableCompletion] is true (and may itself legitimately be
  /// null even then, if this was the item's first-ever completion).
  final DateTime? preCompletionLastCompletedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  Renewal copyWith({
    RenewalType? type,
    String? label,
    DateTime? dueDate,
    String? notes,
    bool clearNotes = false,
    CustomTier? customTier,
    int? healthRecurrenceMonths,
    bool? isDone,
    DateTime? lastCompletedAt,
    bool? pendingRecurrenceDecision,
    bool? hasUndoableCompletion,
    DateTime? preCompletionDueDate,
    DateTime? preCompletionLastCompletedAt,
    DateTime? updatedAt,
  }) {
    return Renewal(
      id: id,
      type: type ?? this.type,
      label: label ?? this.label,
      dueDate: dueDate ?? this.dueDate,
      notes: clearNotes ? null : (notes ?? this.notes),
      customTier: customTier ?? this.customTier,
      healthRecurrenceMonths: healthRecurrenceMonths ?? this.healthRecurrenceMonths,
      isDone: isDone ?? this.isDone,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      pendingRecurrenceDecision: pendingRecurrenceDecision ?? this.pendingRecurrenceDecision,
      hasUndoableCompletion: hasUndoableCompletion ?? this.hasUndoableCompletion,
      preCompletionDueDate: preCompletionDueDate ?? this.preCompletionDueDate,
      preCompletionLastCompletedAt: preCompletionLastCompletedAt ?? this.preCompletionLastCompletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
