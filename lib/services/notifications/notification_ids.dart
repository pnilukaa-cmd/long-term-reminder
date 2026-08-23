/// Android notification-id allocation.
///
/// Per-occurrence notifications use `scheduled_notifications.id` (the drift
/// autoincrement row id) directly as their Android notification id — see
/// that table's doc comment in `lib/data/database/tables.dart` for why no
/// second `androidNotificationId` column exists.
///
/// Group-summary notifications (REQ-12.1) need their own id, one per
/// calendar day, that's deterministic across reconciliation passes (so
/// re-posting/cancelling the same day's summary is idempotent) and that
/// can never collide with a real row id.
class NotificationIds {
  const NotificationIds._();

  /// Deliberately **not** `String.hashCode` — Dart's spec doesn't guarantee
  /// that algorithm is stable across SDK versions, and a summary id that
  /// silently changed between app updates would leave a stale, un-cancellable
  /// duplicate notification behind. This is a plain, monotonic day-index
  /// computed from the calendar date itself, so it's stable by construction.
  ///
  /// The `100000000` offset keeps this id space well clear of realistic
  /// `scheduled_notifications` row ids (a solo local-only app; thousands of
  /// rows would already be an extreme outlier for this product). Flagged
  /// explicitly as an assumption, not a guarantee, in the developer handoff.
  static int summaryIdFor(String groupDateKey) {
    final parts = groupDateKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final dayIndex = year * 372 + month * 31 + day; // 372 = 12 * 31, a generous per-month bucket
    return 100000000 + dayIndex;
  }
}
