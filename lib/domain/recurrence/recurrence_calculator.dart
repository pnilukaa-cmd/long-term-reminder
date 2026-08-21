import '../models/date_math.dart';
import '../models/renewal_type.dart';

/// The set of choices offered on the mark-done recurrence bottom sheet for
/// a given type, per docs/design/02-v1-design.md §4/§2a and
/// docs/requirements/03-v1-acceptance-criteria.md REQ-9.1–9.4.
enum RecurrenceUiKind {
  /// Warranty: no sheet at all — item goes straight to Done (REQ-9.3).
  none,

  /// Insurance/Vehicle/Licence/Passport/Health check: a one-tap smart
  /// default plus a manual date-picker fallback (REQ-9.1/9.2, §2a).
  smartDefaultWithManualOption,

  /// Custom: a yes/no "does this repeat?" prompt first; "yes" leads to a
  /// manual-date-only picker (no smart default exists), "no" behaves like
  /// Warranty (REQ-9.4).
  yesNoThenManualOnly,
}

/// Pure recurrence math: computing the smart-default next due date, and
/// describing which UI flow a type uses. Kept separate from any bottom
/// sheet widget so it's unit testable without pumping a widget tree.
class RecurrenceCalculator {
  const RecurrenceCalculator._();

  static RecurrenceUiKind uiKindFor(RenewalType type) {
    switch (type) {
      case RenewalType.warranty:
        return RecurrenceUiKind.none;
      case RenewalType.custom:
        return RecurrenceUiKind.yesNoThenManualOnly;
      case RenewalType.passport:
      case RenewalType.insurance:
      case RenewalType.licence:
      case RenewalType.vehicle:
      case RenewalType.healthCheck:
        return RecurrenceUiKind.smartDefaultWithManualOption;
    }
  }

  /// REQ-9.1: the smart default is always computed from the item's
  /// *original due date*, never from "today" or the completion date — so
  /// marking something done early or late doesn't change the next cycle's
  /// date. Returns null for types with no smart default (Warranty has no
  /// sheet at all; Custom never offers one — REQ-9.4).
  ///
  /// [healthRecurrenceMonths] is required (and only meaningful) for
  /// [RenewalType.healthCheck] — REQ-9.1's worked example: a due date of
  /// 14 May 2027 with a stored interval of 12 months computes to
  /// 14 May 2028, sourced from the item's own stored setting, never a
  /// freshly computed suggestion (design doc §2a/§4).
  static DateTime? smartDefaultNextDueDate({
    required RenewalType type,
    required DateTime dueDate,
    int? healthRecurrenceMonths,
  }) {
    switch (type) {
      case RenewalType.passport:
        return addYears(dueDate, 10);
      case RenewalType.insurance:
      case RenewalType.vehicle:
      case RenewalType.licence:
        return addYears(dueDate, 1);
      case RenewalType.healthCheck:
        assert(healthRecurrenceMonths != null, 'Health check requires a stored recurrence interval');
        return addMonths(dueDate, healthRecurrenceMonths ?? 12);
      case RenewalType.warranty:
      case RenewalType.custom:
        return null;
    }
  }

  /// Label for the smart-default option's headline, matching the mockup's
  /// wording pattern ("Same time next year" / "+10 years" /
  /// "Same as your setting — In N months").
  static String smartDefaultLabel({
    required RenewalType type,
    int? healthRecurrenceMonths,
  }) {
    switch (type) {
      case RenewalType.passport:
        return '+10 years';
      case RenewalType.insurance:
      case RenewalType.vehicle:
      case RenewalType.licence:
        return 'Same time next year';
      case RenewalType.healthCheck:
        return 'Same as your setting — In ${healthRecurrenceMonths ?? 12} months';
      case RenewalType.warranty:
      case RenewalType.custom:
        return '';
    }
  }
}
