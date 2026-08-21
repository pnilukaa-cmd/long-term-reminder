/// Calendar-aware date arithmetic shared by the ladder and recurrence
/// calculators. Kept separate and dependency-free so it's trivially unit
/// testable.
library;

/// Returns [date] with [months] calendar months added (or subtracted, if
/// negative). Clamps the day-of-month to the last valid day of the target
/// month rather than letting it silently roll into the following month
/// (Dart's raw `DateTime(y, m, d)` constructor would turn "30 Feb" into
/// "2 Mar", which reads as a different, wrong due date to a user).
DateTime addMonths(DateTime date, int months) {
  final totalMonths = (date.year * 12 + (date.month - 1)) + months;
  final targetYear = totalMonths ~/ 12;
  final targetMonth = (totalMonths % 12) + 1;
  final lastDayOfTargetMonth = _daysInMonth(targetYear, targetMonth);
  final targetDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
  return DateTime(
    targetYear,
    targetMonth,
    targetDay,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// Returns [date] with [years] calendar years added (or subtracted).
/// Handles the 29 Feb leap-year edge case the same clamped way as
/// [addMonths].
DateTime addYears(DateTime date, int years) => addMonths(date, years * 12);

int _daysInMonth(int year, int month) {
  // Day 0 of the *next* month is the last day of this month.
  final firstOfNextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return firstOfNextMonth.subtract(const Duration(days: 1)).day;
}

/// Strips the time-of-day component, returning a date at local midnight.
/// Every acceptance criterion in this project is written at day
/// granularity ("due in N days"), never hour/minute — comparisons should
/// use this rather than raw `DateTime` comparison, which would be sensitive
/// to time-of-day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whole-day difference between two dates, ignoring time-of-day.
/// Positive when [to] is after [from].
int daysBetween(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  return b.difference(a).inDays;
}
