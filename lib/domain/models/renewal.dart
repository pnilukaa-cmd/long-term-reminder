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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
