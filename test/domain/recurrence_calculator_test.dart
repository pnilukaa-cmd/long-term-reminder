import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/domain/recurrence/recurrence_calculator.dart';

void main() {
  group('RecurrenceCalculator.uiKindFor — REQ-9', () {
    test('Warranty has no recurrence UI at all (REQ-9.3)', () {
      expect(RecurrenceCalculator.uiKindFor(RenewalType.warranty), RecurrenceUiKind.none);
    });

    test('Custom asks yes/no first (REQ-9.4)', () {
      expect(RecurrenceCalculator.uiKindFor(RenewalType.custom), RecurrenceUiKind.yesNoThenManualOnly);
    });

    test('Recurring types offer a smart default plus manual option (REQ-9.1/9.2)', () {
      for (final type in [
        RenewalType.passport,
        RenewalType.insurance,
        RenewalType.licence,
        RenewalType.vehicle,
        RenewalType.healthCheck,
      ]) {
        expect(RecurrenceCalculator.uiKindFor(type), RecurrenceUiKind.smartDefaultWithManualOption);
      }
    });
  });

  group('RecurrenceCalculator.smartDefaultNextDueDate — REQ-9.1', () {
    test('Passport smart default is +10 years from the ORIGINAL due date, not today', () {
      // Item due 12 Dec 2026, marked done early on 1 Dec 2026 — the smart
      // default must still be computed from the due date, per REQ-9.1's
      // worked example.
      final next = RecurrenceCalculator.smartDefaultNextDueDate(
        type: RenewalType.passport,
        dueDate: DateTime(2026, 12, 12),
      );
      expect(next, DateTime(2036, 12, 12));
    });

    test('Insurance/Vehicle/Licence smart default is +1 year from the due date', () {
      for (final type in [RenewalType.insurance, RenewalType.vehicle, RenewalType.licence]) {
        final next = RecurrenceCalculator.smartDefaultNextDueDate(type: type, dueDate: DateTime(2027, 3, 21));
        expect(next, DateTime(2028, 3, 21), reason: type.name);
      }
    });

    test('Health check smart default uses the stored interval, not a fresh suggestion (REQ-9.1 worked example)', () {
      final next = RecurrenceCalculator.smartDefaultNextDueDate(
        type: RenewalType.healthCheck,
        dueDate: DateTime(2027, 5, 14),
        healthRecurrenceMonths: 12,
      );
      expect(next, DateTime(2028, 5, 14));
    });

    test('Warranty and Custom have no smart default', () {
      expect(
        RecurrenceCalculator.smartDefaultNextDueDate(type: RenewalType.warranty, dueDate: DateTime(2027, 1, 1)),
        isNull,
      );
      expect(
        RecurrenceCalculator.smartDefaultNextDueDate(type: RenewalType.custom, dueDate: DateTime(2027, 1, 1)),
        isNull,
      );
    });
  });
}
