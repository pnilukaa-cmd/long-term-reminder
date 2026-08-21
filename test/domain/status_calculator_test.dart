import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/domain/models/renewal_status.dart';
import 'package:long_term_reminder/domain/status/status_calculator.dart';

void main() {
  group('StatusCalculator.computeStatus — REQ-4.2', () {
    test('isDone always wins, regardless of due date', () {
      final status = StatusCalculator.computeStatus(
        type: RenewalType.warranty,
        dueDate: DateTime(2020, 1, 1), // long overdue
        isDone: true,
        now: DateTime(2027, 1, 1),
      );
      expect(status, RenewalStatus.done);
    });

    test('a due date in the past (not done) is Overdue', () {
      final status = StatusCalculator.computeStatus(
        type: RenewalType.insurance,
        dueDate: DateTime(2027, 1, 1),
        isDone: false,
        now: DateTime(2027, 1, 5),
      );
      expect(status, RenewalStatus.overdue);
    });

    test('due today counts as Overdue, not Due soon (day-granularity rule)', () {
      final status = StatusCalculator.computeStatus(
        type: RenewalType.insurance,
        dueDate: DateTime(2027, 1, 5),
        isDone: false,
        now: DateTime(2027, 1, 5),
      );
      expect(status, RenewalStatus.overdue);
    });

    test('Due soon once the closest-to-due ladder stage has fired (BA default)', () {
      // Vehicle's closest stage is 3 days before due.
      final dueDate = DateTime(2027, 7, 2);
      final status = StatusCalculator.computeStatus(
        type: RenewalType.vehicle,
        dueDate: dueDate,
        isDone: false,
        now: DateTime(2027, 6, 30), // exactly 2 days before due — inside the 3-day window
      );
      expect(status, RenewalStatus.dueSoon);
    });

    test('Upcoming before the closest-to-due stage has fired', () {
      final dueDate = DateTime(2027, 7, 2);
      final status = StatusCalculator.computeStatus(
        type: RenewalType.vehicle,
        dueDate: dueDate,
        isDone: false,
        now: DateTime(2027, 6, 1), // well before the 3-day-before window
      );
      expect(status, RenewalStatus.upcoming);
    });

    test('a backdated item (created already overdue, REQ-17.1) is Overdue immediately', () {
      final status = StatusCalculator.computeStatus(
        type: RenewalType.insurance,
        dueDate: DateTime(2026, 1, 1),
        isDone: false,
        now: DateTime(2027, 1, 1),
      );
      expect(status, RenewalStatus.overdue);
    });
  });
}
