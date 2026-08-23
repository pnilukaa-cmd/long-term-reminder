import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/custom_tier.dart';
import 'package:long_term_reminder/domain/models/renewal.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/domain/notifications/notification_stage.dart';
import 'package:long_term_reminder/domain/notifications/reconciliation_planner.dart';

Renewal _item({
  int id = 1,
  RenewalType type = RenewalType.vehicle,
  required DateTime dueDate,
  bool isDone = false,
  DateTime? lastCompletedAt,
  bool pendingRecurrenceDecision = false,
  CustomTier? customTier,
}) {
  final now = DateTime(2020, 1, 1);
  return Renewal(
    id: id,
    type: type,
    label: 'Test item',
    dueDate: dueDate,
    isDone: isDone,
    lastCompletedAt: lastCompletedAt,
    pendingRecurrenceDecision: pendingRecurrenceDecision,
    customTier: customTier,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ReconciliationPlanner.planFor — pre-due ladder (REQ-3.1)', () {
    test('a far-future item gets every ladder stage', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 7, 2))],
        now: DateTime(2027, 1, 1),
        isEntitled: true,
      );
      // Vehicle: 30/14/3 days before.
      expect(plan.map((e) => e.stageKey), ['ladder:0', 'ladder:1', 'ladder:2']);
      expect(plan.every((e) => e.kind == NotificationKind.ladderStage), isTrue);
    });

    test('a stage whose date has already passed is silently skipped, not fired retroactively', () {
      // Vehicle due in 10 days — the 30- and 14-day stages are already in
      // the past relative to "now"; only the 3-day stage remains.
      final dueDate = DateTime(2027, 7, 2);
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: dueDate)],
        now: DateTime(2027, 6, 22),
        isEntitled: true,
      );
      expect(plan.map((e) => e.stageKey), ['ladder:2']);
      expect(plan.single.fireOn, DateTime(2027, 6, 29));
    });

    test('a fully-past item (all stages behind "now") yields no ladder entries at all', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 7, 2))],
        now: DateTime(2027, 7, 1), // 1 day before due — every stage has passed
        isEntitled: true,
      );
      expect(plan, isEmpty);
    });
  });

  group('ReconciliationPlanner.planFor — overdue follow-through (REQ-3.3, REQ-17.1)', () {
    test('an item overdue by exactly the Day-0 nag gets only Day 0, dated on the due date', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(type: RenewalType.warranty, dueDate: DateTime(2027, 1, 1))],
        now: DateTime(2027, 1, 1),
        isEntitled: true,
      );
      expect(plan, hasLength(1));
      expect(plan.single.stageKey, 'overdue:0');
      expect(plan.single.fireOn, DateTime(2027, 1, 1));
    });

    test('REQ-17.1: a deeply backdated item still gets an immediate Day-0 nag, clamped to "today"', () {
      // Due date is 6 months in the past — every dated overdue offset
      // (0/3/10/30 for Vehicle) is long gone, but the Day-0 nag must still
      // fire "immediately," not be skipped like the others.
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2026, 1, 1))],
        now: DateTime(2026, 7, 1),
        isEntitled: true,
      );
      expect(plan, hasLength(1), reason: 'only the clamped Day-0 nag should survive; +3/+10/+30 are all stale');
      expect(plan.single.stageKey, 'overdue:0');
      expect(plan.single.fireOn, DateTime(2026, 7, 1), reason: 'clamped forward to "today", not the stale due date');
    });

    test('later overdue stages still in the future are scheduled normally alongside a clamped Day 0', () {
      // Vehicle due 5 days ago: Day 0 is already past (clamped to today),
      // +3d is also already past (skipped), +10d and +30d are still ahead.
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 6, 1))],
        now: DateTime(2027, 6, 6),
        isEntitled: true,
      );
      expect(plan.map((e) => e.stageKey), ['overdue:0', 'overdue:2', 'overdue:3']);
    });

    test('an item past the end of its overdue sequence yields nothing further (REQ-3.3)', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(type: RenewalType.warranty, dueDate: DateTime(2027, 1, 1))],
        now: DateTime(2027, 6, 1), // Warranty only ever nags once, at Day 0
        isEntitled: true,
      );
      expect(plan, isEmpty);
    });
  });

  group('ReconciliationPlanner.planFor — the §3d bug, at the planner level', () {
    test(
      'a recurring item that just advanced to its next cycle (isDone=false, future due date) '
      'is scheduled exactly like any other upcoming item — Done never suppresses it',
      () {
        // This is what RenewalDao.markDone now produces for a recurring
        // mark-done: isDone stays false, dueDate moves to the next cycle.
        final plan = ReconciliationPlanner.planFor(
          items: [_item(dueDate: DateTime(2028, 3, 21), lastCompletedAt: DateTime(2027, 3, 20))],
          now: DateTime(2027, 3, 21),
          isEntitled: true,
        );
        expect(plan, isNotEmpty, reason: 'the next cycle must be scheduled normally, not suppressed');
        expect(plan.every((e) => e.kind == NotificationKind.ladderStage), isTrue);
      },
    );

    test('a genuinely terminal Done item (isDone=true) is never scheduled, regardless of due date', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2020, 1, 1), isDone: true)],
        now: DateTime(2027, 1, 1),
        isEntitled: true,
      );
      expect(plan, isEmpty);
    });
  });

  group(
    'ReconciliationPlanner.planFor — pendingRecurrenceDecision suppression '
    '(developer task brief item 3 / REQ-9.5, resolving the recurring mark-done gap)',
    () {
      test(
        'an item awaiting its deferred recurrence decision is never scheduled, '
        'even though isDone is still false and the due date is unchanged',
        () {
          // This is exactly the state NotificationActionHandler leaves a
          // recurring item in immediately after cancelling its remaining
          // pending notifications: isDone still false, dueDate still the
          // old (likely overdue) one, but pendingRecurrenceDecision now
          // true. Without this suppression, the very next reconciliation
          // pass (which that same handler triggers) would recompute and
          // silently re-arm the notifications just cancelled.
          final plan = ReconciliationPlanner.planFor(
            items: [_item(dueDate: DateTime(2027, 1, 1), pendingRecurrenceDecision: true)],
            now: DateTime(2027, 1, 5), // overdue — would otherwise get overdue nags
            isEntitled: true,
          );
          expect(plan, isEmpty);
        },
      );

      test('the same item is scheduled normally again once the flag clears (banner resolved)', () {
        final plan = ReconciliationPlanner.planFor(
          items: [_item(dueDate: DateTime(2028, 1, 1))],
          now: DateTime(2027, 1, 5),
          isEntitled: true,
        );
        expect(plan, isNotEmpty);
      });
    },
  );

  group('ReconciliationPlanner.planFor — REQ-16.1 edit side effects, expressed as statelessness', () {
    test('editing a due date forward out of Overdue status stops overdue nags and resumes the ladder', () {
      // Same item, before and after an edit that moves the due date into
      // the future — the planner has no memory, so this is just two
      // independent calls with different input, which is the point.
      final overdueItem = _item(dueDate: DateTime(2027, 1, 1));
      final editedItem = _item(dueDate: DateTime(2027, 8, 1));
      final now = DateTime(2027, 1, 5);

      final beforeEdit = ReconciliationPlanner.planFor(items: [overdueItem], now: now, isEntitled: true);
      expect(beforeEdit.every((e) => e.kind == NotificationKind.overdueNag), isTrue);

      final afterEdit = ReconciliationPlanner.planFor(items: [editedItem], now: now, isEntitled: true);
      expect(afterEdit.every((e) => e.kind == NotificationKind.ladderStage), isTrue);
    });
  });

  group('ReconciliationPlanner.planFor — free/paid entitlement gating (REQ-3.2/3.3, this slice)', () {
    test('a free-tier item pre-due gets exactly one stage, using the type-tuned free offset', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 7, 6))],
        now: DateTime(2027, 1, 1),
        isEntitled: false,
      );
      // Vehicle's free reminder is 14 days before due (LadderTables.freeReminderOffset).
      expect(plan, hasLength(1));
      expect(plan.single.stageKey, 'free:0');
      expect(plan.single.fireOn, DateTime(2027, 6, 22));
    });

    test('a free-tier item skips its single reminder if that date has already passed, same rule as paid', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 6, 25))], // 14-day free stage would be Jun 11, already past
        now: DateTime(2027, 6, 20),
        isEntitled: false,
      );
      expect(plan, isEmpty);
    });

    test('a free-tier item that is overdue gets no notification at all — REQ-3.3 is explicit about this', () {
      final plan = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 1, 1))],
        now: DateTime(2027, 3, 1),
        isEntitled: false,
      );
      expect(plan, isEmpty);
    });

    test('a paid-tier item gets the full ladder plus overdue nags — unaffected by the free-tier rules above', () {
      final preDue = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 7, 6))],
        now: DateTime(2027, 1, 1),
        isEntitled: true,
      );
      expect(preDue, hasLength(3), reason: 'Vehicle: 30/14/3 days before, all paid stages');

      final overdue = ReconciliationPlanner.planFor(
        items: [_item(dueDate: DateTime(2027, 1, 1))],
        now: DateTime(2027, 3, 1),
        isEntitled: true,
      );
      expect(overdue, isNotEmpty, reason: 'paid overdue follow-through must still fire');
    });

    test("Custom's free reminder respects the selected tier, not a fixed default (REQ-2.5)", () {
      final shortPlan = ReconciliationPlanner.planFor(
        items: [_item(type: RenewalType.custom, customTier: CustomTier.short, dueDate: DateTime(2027, 7, 10))],
        now: DateTime(2027, 1, 1),
        isEntitled: false,
      );
      final longPlan = ReconciliationPlanner.planFor(
        items: [_item(type: RenewalType.custom, customTier: CustomTier.long, dueDate: DateTime(2027, 7, 10))],
        now: DateTime(2027, 1, 1),
        isEntitled: false,
      );
      // Short's free reminder is 3 days before; Long's is 30 days before.
      expect(shortPlan.single.fireOn, DateTime(2027, 7, 7));
      expect(longPlan.single.fireOn, DateTime(2027, 6, 10));
    });

    test(
      'REQ-14.2/17.3: the same item transitions cleanly between free and paid stage keys across two calls '
      '(unlock or entitlement loss), never mixing a stale stageKey namespace',
      () {
        final free = ReconciliationPlanner.planFor(
          items: [_item(dueDate: DateTime(2027, 7, 6))],
          now: DateTime(2027, 1, 1),
          isEntitled: false,
        );
        final paid = ReconciliationPlanner.planFor(
          items: [_item(dueDate: DateTime(2027, 7, 6))],
          now: DateTime(2027, 1, 1),
          isEntitled: true,
        );
        expect(free.single.stageKey, 'free:0');
        expect(paid.map((e) => e.stageKey), ['ladder:0', 'ladder:1', 'ladder:2']);
        expect(free.map((e) => e.stageKey).toSet().intersection(paid.map((e) => e.stageKey).toSet()), isEmpty);
      },
    );
  });

  group('DesiredNotification.groupDateKey — REQ-12.1', () {
    test('two items due the same calendar day share a group key', () {
      final plan = ReconciliationPlanner.planFor(
        items: [
          _item(id: 1, type: RenewalType.warranty, dueDate: DateTime(2027, 6, 1)),
          _item(id: 2, type: RenewalType.warranty, dueDate: DateTime(2027, 6, 1)),
        ],
        now: DateTime(2027, 6, 1),
        isEntitled: true,
      );
      expect(plan, hasLength(2));
      expect(plan[0].groupDateKey, plan[1].groupDateKey);
      expect(plan[0].groupDateKey, '2027-06-01');
    });
  });
}
