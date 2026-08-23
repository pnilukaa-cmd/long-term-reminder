/// Android notification action ids — REQ-11.3/REQ-9.5. `Mark done` is the
/// only action in v1 (Snooze is cut — see notification_stage.dart's class
/// doc); this is deliberately a class of one constant, not an enum, so a
/// future action id is just one more line here, not a new type.
class NotificationActionIds {
  const NotificationActionIds._();

  static const String markDone = 'mark_done';
}
