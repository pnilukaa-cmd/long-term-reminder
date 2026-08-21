import 'date_math.dart';

/// The unit a [LadderOffset] is expressed in. Design doc §2's table mixes
/// days, weeks, and months per type (e.g. Passport's ladder is expressed in
/// months, Insurance's in days) — keeping the unit explicit means "1 month
/// before" is computed as a real calendar month, not a naive 30-day
/// multiplication.
enum OffsetUnit { days, weeks, months }

/// A single "N [unit] before the due date" ladder stage, e.g. "30 days
/// before" or "3 months before".
class LadderOffset {
  const LadderOffset(this.value, this.unit) : assert(value > 0, 'A ladder offset must be a positive amount of lead time');

  final int value;
  final OffsetUnit unit;

  /// The calendar date this stage falls on, relative to [dueDate].
  DateTime dateBefore(DateTime dueDate) {
    switch (unit) {
      case OffsetUnit.days:
        return dueDate.subtract(Duration(days: value));
      case OffsetUnit.weeks:
        return dueDate.subtract(Duration(days: value * 7));
      case OffsetUnit.months:
        return addMonths(dueDate, -value);
    }
  }

  /// Human-readable label matching the mockups' stage-chip copy, e.g.
  /// "30 days before", "1 week before", "3 months before".
  String get label {
    final unitWord = _unitWord(value);
    return '$value $unitWord before';
  }

  String _unitWord(int value) {
    final singular = value == 1;
    switch (unit) {
      case OffsetUnit.days:
        return singular ? 'day' : 'days';
      case OffsetUnit.weeks:
        return singular ? 'week' : 'weeks';
      case OffsetUnit.months:
        return singular ? 'month' : 'months';
    }
  }

  @override
  bool operator ==(Object other) => other is LadderOffset && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'LadderOffset($value, $unit)';
}
