import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/database/app_database.dart';
import '../../data/database/notification_dao.dart';
import '../../services/notifications/notification_service.dart';

/// Task brief item 7 — "a debug-only screen or log dumping what the app
/// believes is scheduled, so a human can diff it against
/// `adb shell dumpsys alarm`." Debug-only: only ever reachable from a
/// `kDebugMode`-gated entry point (see `HomeScreen`'s app bar) — never
/// linked from any user-facing flow.
///
/// Shows two independently-sourced lists side by side, deliberately not
/// merged into one reconciled view — the entire point is to let a human
/// spot a *mismatch* between them, which a pre-merged view would hide:
/// 1. **This app's belief** — every row in `scheduled_notifications`,
///    straight from the database (the source of truth per the scheduling
///    ADR §2).
/// 2. **The plugin's belief** — `flutter_local_notifications`'
///    `pendingNotificationRequests()`, i.e. what `flutter_local_notifications`
///    itself thinks it has scheduled with the OS.
///
/// Neither of these is `adb shell dumpsys alarm` (what Android's
/// `AlarmManager` actually has registered) — that's the real ground truth
/// named in the device-verification checklist
/// (docs/technical/04-scheduling-and-stack.md §6), and it can only be read
/// from a host machine's adb, not from inside the app. This screen exists
/// to make the *other* two views inspectable on-device so a tester can
/// diff all three without guessing at what the app's internal state even
/// is.
class ScheduledStateDebugScreen extends StatefulWidget {
  const ScheduledStateDebugScreen({
    super.key,
    required this.notificationDao,
    required this.notificationService,
  });

  final NotificationDao notificationDao;
  final NotificationService notificationService;

  @override
  State<ScheduledStateDebugScreen> createState() => _ScheduledStateDebugScreenState();
}

class _ScheduledStateDebugScreenState extends State<ScheduledStateDebugScreen> {
  late Future<_DebugSnapshot> _snapshot = _load();

  Future<_DebugSnapshot> _load() async {
    final rows = await widget.notificationDao.getAllRows();
    final pending = await widget.notificationService.pendingRequests();
    return _DebugSnapshot(rows: rows, pending: pending);
  }

  void _refresh() => setState(() => _snapshot = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled state (debug)'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: FutureBuilder<_DebugSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('scheduled_notifications (${data.rows.length} rows)', style: _sectionStyle),
              const SizedBox(height: 8),
              if (data.rows.isEmpty) const Text('No rows.'),
              for (final row in data.rows) _RowTile(row),
              const SizedBox(height: 24),
              Text('flutter_local_notifications.pendingNotificationRequests() (${data.pending.length})',
                  style: _sectionStyle),
              const SizedBox(height: 8),
              if (data.pending.isEmpty) const Text('No pending requests reported by the plugin.'),
              for (final p in data.pending)
                ListTile(
                  dense: true,
                  leading: Text('#${p.id}'),
                  title: Text(p.title ?? '(no title)'),
                  subtitle: Text(p.payload == null ? '(no payload)' : 'payload: ${p.payload}'),
                ),
              const SizedBox(height: 24),
              const Text(
                'Cross-check against the device itself:\n'
                'adb shell dumpsys alarm | grep <applicationId>\n\n'
                'Neither list above IS that ground truth — this screen only '
                'shows what this app and the plugin each *believe*.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _sectionStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);
}

class _DebugSnapshot {
  const _DebugSnapshot({required this.rows, required this.pending});
  final List<ScheduledNotification> rows;
  final List<PendingNotificationRequest> pending;
}

class _RowTile extends StatelessWidget {
  const _RowTile(this.row);
  final ScheduledNotification row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Text('#${row.id}'),
      title: Text('renewal ${row.renewalId} · ${row.kind} · ${row.stageKey}'),
      subtitle: Text(
        'fireOn: ${row.fireOn.toIso8601String()}\n'
        'group: ${row.groupDateKey} · status: ${row.status}',
      ),
      isThreeLine: true,
      trailing: _StatusChip(row.status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.blue,
      'fired' => Colors.green,
      'skipped' => Colors.orange,
      'cancelled' => Colors.grey,
      _ => Colors.red,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: .15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
