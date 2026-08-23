import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/domain/notifications/notification_diff.dart';
import 'package:long_term_reminder/domain/notifications/notification_stage.dart';

DesiredNotification _desired({
  int renewalId = 1,
  String stageKey = 'ladder:0',
  required DateTime fireOn,
}) {
  return DesiredNotification(
    renewalId: renewalId,
    renewalType: RenewalType.vehicle,
    itemLabel: 'Test item',
    kind: NotificationKind.ladderStage,
    stageKey: stageKey,
    fireOn: fireOn,
    title: 'title',
    body: 'body',
    expandedLineText: 'expanded',
  );
}

ExistingScheduledRow _row({
  int id = 1,
  int renewalId = 1,
  String stageKey = 'ladder:0',
  required DateTime fireOn,
  String status = 'pending',
  String groupDateKey = '2027-01-01',
}) {
  return ExistingScheduledRow(
    id: id,
    renewalId: renewalId,
    stageKey: stageKey,
    fireOn: fireOn,
    status: status,
    groupDateKey: groupDateKey,
  );
}

void main() {
  group('NotificationDiffEngine.diff — new/unchanged/moved occurrences', () {
    test('a desired occurrence with no existing row is inserted and armed', () {
      final actions = NotificationDiffEngine.diff(
        desired: [_desired(fireOn: DateTime(2027, 6, 1))],
        existingRows: const [],
        activeRenewalIds: {1},
        today: DateTime(2027, 5, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.insertAndArm);
    });

    test('a pending row with the same stageKey and fireOn is re-armed (self-heal), not duplicated', () {
      final actions = NotificationDiffEngine.diff(
        desired: [_desired(fireOn: DateTime(2027, 6, 1))],
        existingRows: [_row(fireOn: DateTime(2027, 6, 1))],
        activeRenewalIds: {1},
        today: DateTime(2027, 5, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.rearm);
      expect(actions.single.existingRowId, 1);
    });

    test('a pending row with the same stageKey but a different fireOn is rescheduled (REQ-16.1 edit)', () {
      final actions = NotificationDiffEngine.diff(
        desired: [_desired(fireOn: DateTime(2027, 7, 1))],
        existingRows: [_row(fireOn: DateTime(2027, 6, 1))],
        activeRenewalIds: {1},
        today: DateTime(2027, 5, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.rescheduleAndArm);
    });

    test('a terminal row whose stageKey comes back into the desired set is revived, not left stale', () {
      final actions = NotificationDiffEngine.diff(
        desired: [_desired(fireOn: DateTime(2027, 8, 1))],
        existingRows: [_row(fireOn: DateTime(2027, 6, 1), status: 'fired')],
        activeRenewalIds: {1},
        today: DateTime(2027, 5, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.rescheduleAndArm);
    });
  });

  group('NotificationDiffEngine.diff — rows that dropped out of the desired set', () {
    test('a still-active item whose stage passed within 2 days is marked fired, not cancelled', () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 5, 30))],
        activeRenewalIds: {1},
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.markFired);
    });

    test('a still-active item whose stage passed more than 2 days ago is marked skipped (REQ-17.2 clock jump)', () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 5, 1))],
        activeRenewalIds: {1},
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.markSkipped);
    });

    test('a row for a renewal that is no longer active (deleted or terminal-Done) is cancelled, not fired/skipped',
        () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 5, 30))],
        activeRenewalIds: const {}, // item 1 no longer active
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.cancel);
    });

    test('a still-future row that drops out of the desired set is cancelled, not marked fired', () {
      // Regression: `today.difference(fireOn).inDays` is negative for a future
      // fireOn, and negative is always <= 2, so this used to fall into the
      // markFired branch. The stage never fired -- it dropped out because the
      // desired set changed (due-date edit, type change, Custom-tier change,
      // or an entitlement transition).
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 9, 1))],
        activeRenewalIds: {1}, // item still active
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.cancel);
    });

    test('a row whose fireOn already passed is still marked fired, not cancelled', () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 5, 31))],
        activeRenewalIds: {1},
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.markFired);
    });

    test('a same-calendar-day fireOn stays in the fired branch -- it may genuinely have fired earlier today', () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 6, 1, 9))],
        activeRenewalIds: {1},
        today: DateTime(2027, 6, 1),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, DiffActionKind.markFired);
    });

    test('a non-pending row that drops out of the desired set produces no action (already terminal)', () {
      final actions = NotificationDiffEngine.diff(
        desired: const [],
        existingRows: [_row(fireOn: DateTime(2027, 5, 30), status: 'cancelled')],
        activeRenewalIds: {1},
        today: DateTime(2027, 6, 1),
      );
      expect(actions, isEmpty);
    });
  });

  test('multiple items are diffed independently by (renewalId, stageKey), not by stageKey alone', () {
    final actions = NotificationDiffEngine.diff(
      desired: [
        _desired(renewalId: 1, stageKey: 'ladder:0', fireOn: DateTime(2027, 6, 1)),
        _desired(renewalId: 2, stageKey: 'ladder:0', fireOn: DateTime(2027, 6, 1)),
      ],
      existingRows: [_row(id: 10, renewalId: 1, stageKey: 'ladder:0', fireOn: DateTime(2027, 6, 1))],
      activeRenewalIds: {1, 2},
      today: DateTime(2027, 5, 1),
    );
    expect(actions, hasLength(2));
    expect(actions.where((a) => a.kind == DiffActionKind.rearm), hasLength(1));
    expect(actions.where((a) => a.kind == DiffActionKind.insertAndArm), hasLength(1));
  });
}
