import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/ladder/ladder_calculator.dart';
import 'package:long_term_reminder/domain/ladder/ladder_tables.dart';
import 'package:long_term_reminder/domain/models/custom_tier.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';

void main() {
  group('LadderTables.paidLadderStages — REQ-3.1', () {
    test('Passport: 6mo/3mo/1mo/1wk', () {
      final stages = LadderTables.paidLadderStages(RenewalType.passport);
      expect(stages.map((s) => s.label).toList(), [
        '6 months before',
        '3 months before',
        '1 month before',
        '1 week before',
      ]);
    });

    test('Insurance: 21/7/1 days', () {
      final stages = LadderTables.paidLadderStages(RenewalType.insurance);
      expect(stages.map((s) => s.value).toList(), [21, 7, 1]);
    });

    test('Warranty: 30/7 days (2 stages only)', () {
      final stages = LadderTables.paidLadderStages(RenewalType.warranty);
      expect(stages.length, 2);
      expect(stages.map((s) => s.value).toList(), [30, 7]);
    });

    test('Custom Short/Medium/Long profiles', () {
      expect(
        LadderTables.paidLadderStages(RenewalType.custom, customTier: CustomTier.short).map((s) => s.value),
        [7, 3, 1],
      );
      expect(
        LadderTables.paidLadderStages(RenewalType.custom, customTier: CustomTier.medium).map((s) => s.value),
        [30, 7, 1],
      );
      expect(
        LadderTables.paidLadderStages(RenewalType.custom, customTier: CustomTier.long).map((s) => s.value),
        [90, 30, 7],
      );
    });

    test('Custom defaults to Medium when no tier is given', () {
      expect(
        LadderTables.paidLadderStages(RenewalType.custom).map((s) => s.value),
        [30, 7, 1],
      );
    });
  });

  group('LadderTables.freeReminderOffset — REQ-3.2', () {
    test('matches the free-tier table', () {
      expect(LadderTables.freeReminderOffset(RenewalType.passport).value, 3);
      expect(LadderTables.freeReminderOffset(RenewalType.insurance).value, 7);
      expect(LadderTables.freeReminderOffset(RenewalType.licence).value, 30);
      expect(LadderTables.freeReminderOffset(RenewalType.vehicle).value, 14);
      expect(LadderTables.freeReminderOffset(RenewalType.warranty).value, 30);
      expect(LadderTables.freeReminderOffset(RenewalType.healthCheck).value, 30);
    });

    test('Custom free reminder scales with the selected tier (§2b)', () {
      expect(LadderTables.freeReminderOffset(RenewalType.custom, customTier: CustomTier.short).value, 3);
      expect(LadderTables.freeReminderOffset(RenewalType.custom, customTier: CustomTier.medium).value, 7);
      expect(LadderTables.freeReminderOffset(RenewalType.custom, customTier: CustomTier.long).value, 30);
    });
  });

  group('LadderTables.overdueNagDaysAfterDue — REQ-3.3', () {
    test('Warranty only nags once (Day 0)', () {
      expect(LadderTables.overdueNagDaysAfterDue(RenewalType.warranty), [0]);
    });

    test('Insurance nags 4 times, widening spacing', () {
      final days = LadderTables.overdueNagDaysAfterDue(RenewalType.insurance);
      expect(days, [0, 3, 10, 30]);
      // Spacing should widen, not tighten (design doc §2's de-escalation rule).
      for (var i = 1; i < days.length - 1; i++) {
        expect(days[i + 1] - days[i], greaterThanOrEqualTo(days[i] - days[i - 1]));
      }
    });

    test('Health check has the lightest still-nagging cadence (2 stages)', () {
      expect(LadderTables.overdueNagDaysAfterDue(RenewalType.healthCheck), [0, 30]);
    });
  });

  group('LadderCalculator.instancesFor', () {
    test('marks stages fired once their date has passed relative to now', () {
      final dueDate = DateTime(2027, 7, 2);
      final now = DateTime(2027, 6, 20); // 12 days before due
      final stages = LadderCalculator.paidLadderInstances(
        type: RenewalType.vehicle, // 30/14/3 days before
        dueDate: dueDate,
        now: now,
      );
      // 30-days-before (Jun 2) and 14-days-before (Jun 18) have passed;
      // 3-days-before (Jun 29) has not.
      expect(stages[0].fired, isTrue);
      expect(stages[1].fired, isTrue);
      expect(stages[2].fired, isFalse);
    });

    test('nextUnfiredStage returns the first stage still in the future', () {
      final dueDate = DateTime(2027, 7, 2);
      final now = DateTime(2027, 6, 20);
      final stages = LadderCalculator.paidLadderInstances(type: RenewalType.vehicle, dueDate: dueDate, now: now);
      final next = LadderCalculator.nextUnfiredStage(stages);
      expect(next?.offset.value, 3);
    });

    test('nextUnfiredStage is null once every stage has fired', () {
      final dueDate = DateTime(2027, 7, 2);
      final now = DateTime(2027, 7, 1); // 1 day before due — every vehicle stage has fired
      final stages = LadderCalculator.paidLadderInstances(type: RenewalType.vehicle, dueDate: dueDate, now: now);
      expect(LadderCalculator.nextUnfiredStage(stages), isNull);
    });

    test('closestToDueStage is the last (nearest-to-due) stage', () {
      final stages = LadderCalculator.paidLadderInstances(
        type: RenewalType.passport,
        dueDate: DateTime(2027, 12, 12),
        now: DateTime(2027, 1, 1),
      );
      expect(stages.last.offset.value, 1);
    });
  });
}
