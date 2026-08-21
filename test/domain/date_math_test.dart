import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/date_math.dart';

void main() {
  group('addMonths', () {
    test('adds whole months within the same year', () {
      expect(addMonths(DateTime(2027, 3, 10), 2), DateTime(2027, 5, 10));
    });

    test('rolls over the year boundary', () {
      expect(addMonths(DateTime(2026, 11, 5), 3), DateTime(2027, 2, 5));
    });

    test('subtracts months (negative input)', () {
      expect(addMonths(DateTime(2027, 2, 5), -3), DateTime(2026, 11, 5));
    });

    test('clamps day-of-month instead of rolling into the next month', () {
      // 31 Jan + 1 month should land on 28/29 Feb, not 2/3 Mar.
      final result = addMonths(DateTime(2027, 1, 31), 1);
      expect(result.month, 2);
      expect(result.day, lessThanOrEqualTo(28));
    });

    test('handles the leap-year 29 Feb edge case', () {
      // 2028 is a leap year; 2027 is not.
      final result = addMonths(DateTime(2028, 2, 29), 12);
      expect(result, DateTime(2029, 2, 28));
    });
  });

  group('addYears', () {
    test('adds whole years', () {
      expect(addYears(DateTime(2026, 12, 12), 10), DateTime(2036, 12, 12));
    });
  });

  group('daysBetween', () {
    test('is positive when the target date is later', () {
      expect(daysBetween(DateTime(2027, 1, 1), DateTime(2027, 1, 11)), 10);
    });

    test('is negative when the target date is earlier (overdue case)', () {
      expect(daysBetween(DateTime(2027, 1, 11), DateTime(2027, 1, 5)), -6);
    });

    test('ignores time-of-day', () {
      expect(daysBetween(DateTime(2027, 1, 1, 23, 59), DateTime(2027, 1, 2, 0, 1)), 1);
    });
  });
}
