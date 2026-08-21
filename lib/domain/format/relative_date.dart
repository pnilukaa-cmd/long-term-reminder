import '../models/date_math.dart';

/// Formats the card-subtitle relative-date strings used on the list screen
/// (e.g. "Due in 12 days · Jul 2", "Was due 6 days ago", "Due in 4
/// months · Dec 2026"), matching the phrasing in
/// docs/design/mockups/01-home-list.html's success-state cards.
///
/// Deliberately not using `intl` — the project has no other need for it in
/// this slice, and a short hand-rolled formatter keeps the dependency list
/// to exactly what the brief asked for.
class RelativeDateFormatter {
  const RelativeDateFormatter._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

  static String longDate(DateTime date) => '${date.day} ${_fullMonth(date.month)} ${date.year}';

  static String _fullMonth(int month) {
    const full = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return full[month - 1];
  }

  /// "Due in N days · Jul 2" / "Due in N months · Dec 2026" / "Was due N
  /// days ago". Uses whole months once the gap crosses ~60 days, mirroring
  /// the mockup's mixed granularity ("Due in 12 days" vs "Due in 4
  /// months").
  static String dueLine(DateTime dueDate, DateTime now) {
    final days = daysBetween(now, dueDate);
    if (days < 0) {
      final overdueBy = -days;
      return overdueBy == 1 ? 'Was due 1 day ago' : 'Was due $overdueBy days ago';
    }
    if (days == 0) return 'Due today';
    if (days < 60) {
      final unit = days == 1 ? 'day' : 'days';
      return 'Due in $days $unit · ${shortDate(dueDate)}';
    }
    final months = (days / 30).round();
    final unit = months == 1 ? 'month' : 'months';
    return 'Due in $months $unit · ${shortDate(dueDate)}';
  }

  /// "Renewed May 14 · next due May 2027" — used for Done cards.
  static String doneLine(DateTime completedAt, DateTime? nextDueDate) {
    final renewed = 'Renewed ${shortDate(completedAt)}';
    if (nextDueDate == null) return renewed;
    return '$renewed · next due ${_monthYear(nextDueDate)}';
  }

  static String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';
}
