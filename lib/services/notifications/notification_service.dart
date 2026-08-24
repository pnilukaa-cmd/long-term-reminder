import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications/notification_copy.dart';
import '../../domain/notifications/notification_stage.dart';
import 'notification_action_ids.dart';
import 'notification_background_handler.dart';

/// The single notification channel this app uses — one channel for both
/// ladder-stage and overdue-nag notifications, since neither the design doc
/// nor the acceptance criteria call for the user to be able to mute one
/// kind independently of the other.
class NotificationChannels {
  const NotificationChannels._();

  static const String remindersChannelId = 'renewal_reminders';
  static const String remindersChannelName = 'Renewal reminders';
  static const String remindersChannelDescription =
      'Ladder-stage and overdue reminders for the renewals you track.';
}

/// Thin wrapper over `flutter_local_notifications`, per
/// docs/technical/04-scheduling-and-stack.md §2/§3. Owns: plugin init and
/// channel setup, timezone setup (REQ-17.2), the Android 13+ permission
/// request, arming/cancelling individual occurrences, and posting/cancelling
/// group-summary notifications (REQ-12.1/12.2). Deliberately has no opinion
/// about *what should* be scheduled — that's [ReconciliationPlanner] /
/// `ReconciliationService`'s job; this class only knows how to make the
/// OS/plugin match whatever it's told.
///
/// **Unverified**: nothing in this file has been run — no Flutter SDK, no
/// device, no emulator exist in this environment. This is written to
/// `flutter_local_notifications` v18's documented API surface (`zonedSchedule`,
/// `AndroidScheduleMode`, `AndroidNotificationAction`, group-summary via
/// `setAsGroupSummary`/`InboxStyleInformation`) but that surface has not
/// been resolved against an actual installed package version.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Invoked when a `Mark done` action is tapped while the app process is
  /// alive (foreground or backgrounded-but-not-killed). Deliberately a
  /// **mutable field**, not a constructor/`init()`-time-only parameter:
  /// `main()` needs to call [init] before `runApp` (so channel/timezone
  /// setup is guaranteed complete before the first frame), but the actual
  /// handler needs the live [RenewalRepository]/[NotificationDao]/
  /// `ReconciliationService` instances that only exist once
  /// `RenewalReminderApp`'s state is constructed — a real chicken-and-egg
  /// problem. Reading this field at callback-fire-time (not capturing it
  /// early) means `app.dart` can assign it in `initState`, after `main()`
  /// has already called [init].
  Future<void> Function(int renewalId)? onMarkDoneWhileAlive;

  /// Delivery hour for every scheduled notification, in the device's local
  /// time. Per the scheduling ADR §1's defensive recommendation: firing in
  /// the morning (not evening) gives inexact-delivery slippage room to
  /// still land same-day, keeping REQ-11.2's same-day contract intact even
  /// under a slipped delivery — applied uniformly to every stage, not just
  /// the sensitive final-before-due one, since there's no reason for the
  /// others to fire at a different, arbitrary hour.
  static const int fireHourLocal = 9;

  /// Registers the plugin, the one notification channel, both
  /// notification-response callbacks (REQ-9.5's `Mark done` action, in both
  /// the live-process and killed-process cases), and `timezone`/
  /// `flutter_timezone` (REQ-17.2). Must run before any [armDesiredNotification]
  /// call. Safe to call more than once — later calls are a no-op.
  ///
  /// The killed-process case is handled entirely by
  /// [notificationBackgroundResponseHandler], which has no dependency on
  /// anything constructed here or on [onMarkDoneWhileAlive].
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to whatever `package:timezone` defaults to if the
      // platform-channel lookup fails for any reason — degraded (REQ-17.2's
      // "correct calendar day in the device's *current* timezone" guarantee
      // weakens to "correct calendar day in the package's default zone")
      // rather than crashing startup over a non-critical lookup. Not
      // verified against a real device.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId != NotificationActionIds.markDone) return;
        final renewalId = int.tryParse(response.payload ?? '');
        if (renewalId == null) return;
        await onMarkDoneWhileAlive?.call(renewalId);
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundResponseHandler,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.remindersChannelId,
        NotificationChannels.remindersChannelName,
        description: NotificationChannels.remindersChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  /// Android 13+ runtime permission (task brief item 6). The caller
  /// (`AddEditScreen`) is responsible for only invoking this after the
  /// user's *first* item is saved, not on first launch. Returns whatever
  /// the plugin reports — `null` on API levels below 33, where there's no
  /// runtime prompt at all and notifications just work; callers should
  /// treat `null` as "nothing to do", not as a denial.
  Future<bool?> requestPermission() {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.requestNotificationsPermission() ?? Future.value(null);
  }

  /// Arms (or re-arms — idempotent, see [DiffActionKind.rearm]'s doc
  /// comment) a single occurrence, using [id] as both the Android
  /// notification id and the corresponding `scheduled_notifications.id`.
  ///
  /// **Inexact alarms only**, per the task brief and the scheduling ADR §1:
  /// `AndroidScheduleMode.inexactAllowWhileIdle`. Never
  /// `exactAllowWhileIdle`/`alarmClock`, and no `SCHEDULE_EXACT_ALARM`
  /// permission flow anywhere in this app — that decision is settled.
  Future<void> armDesiredNotification({required int id, required DesiredNotification desired}) {
    final scheduledTime = _toTzDateTime(desired.fireOn);
    return _plugin.zonedSchedule(
      id,
      desired.title,
      desired.body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.remindersChannelId,
          NotificationChannels.remindersChannelName,
          channelDescription: NotificationChannels.remindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          groupKey: desired.groupDateKey,
          actions: const [
            AndroidNotificationAction(NotificationActionIds.markDone, 'Mark done'),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Required by flutter_local_notifications 18's `zonedSchedule`. iOS-only
      // semantics (how a wall-clock time is read across a timezone change);
      // absoluteTime is the correct reading for a reminder tied to a real
      // date rather than to a local time-of-day ritual. Inert on Android.
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: desired.renewalId.toString(),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// REQ-12.1's collapsed group-summary notification — posted/updated
  /// (`FlutterLocalNotificationsPlugin.show` overwrites an existing
  /// notification sharing the same id) whenever 2+ items' notifications
  /// land on the same calendar day; the caller cancels it once that's no
  /// longer true. [summaryId] should come from [NotificationIds.summaryIdFor]
  /// so it's stable across reconciliation passes and never collides with a
  /// real per-occurrence id.
  Future<void> postGroupSummary({
    required int summaryId,
    required String groupDateKey,
    required List<String> itemLabels,
  }) {
    final title = NotificationCopy.groupSummaryTitle(itemLabels.length);
    final body = NotificationCopy.groupSummaryBody(itemLabels);
    return _plugin.show(
      summaryId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.remindersChannelId,
          NotificationChannels.remindersChannelName,
          channelDescription: NotificationChannels.remindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          groupKey: groupDateKey,
          setAsGroupSummary: true,
          styleInformation: InboxStyleInformation(itemLabels, contentTitle: title, summaryText: body),
        ),
      ),
    );
  }

  /// What the OS/plugin currently reports as pending — the other half of
  /// the debug scheduled-state screen (task item 7), meant to be diffed by
  /// a human against this app's own `scheduled_notifications` table and
  /// against `adb shell dumpsys alarm`.
  Future<List<PendingNotificationRequest>> pendingRequests() => _plugin.pendingNotificationRequests();

  tz.TZDateTime _toTzDateTime(DateTime calendarDay) {
    final local = DateTime(calendarDay.year, calendarDay.month, calendarDay.day, fireHourLocal);
    var scheduled = tz.TZDateTime.from(local, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(now)) {
      // A Day-0 nag (or any stage) whose target date is today, armed after
      // this run's fixed morning hour has already passed — or reconciliation
      // simply running later in the day — must still fire promptly rather
      // than silently never firing because the requested time is in the
      // past. Clamped a minute out; `zonedSchedule` requires a future time.
      scheduled = now.add(const Duration(minutes: 1));
    }
    return scheduled;
  }
}
