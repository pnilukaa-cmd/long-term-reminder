/// The seven preset renewal types this app tracks, per
/// docs/design/02-v1-design.md §2 / §6 and
/// docs/requirements/03-v1-acceptance-criteria.md §4.
///
/// The `name` of each enum value is used as the persisted string in the
/// database (see `lib/data/database/tables.dart`) — do not rename existing
/// values without a migration.
enum RenewalType {
  passport,
  insurance,
  licence,
  vehicle,
  warranty,
  healthCheck,
  custom;

  /// Display label used in the type-selection row and elsewhere.
  String get displayName {
    switch (this) {
      case RenewalType.passport:
        return 'Passport / Travel ID';
      case RenewalType.insurance:
        return 'Insurance';
      case RenewalType.licence:
        return 'Professional Licence';
      case RenewalType.vehicle:
        return 'Vehicle';
      case RenewalType.warranty:
        return 'Warranty';
      case RenewalType.healthCheck:
        return 'Health check';
      case RenewalType.custom:
        return 'Custom / something else';
    }
  }

  /// Shorter label for tight spaces (type chips).
  String get shortName {
    switch (this) {
      case RenewalType.passport:
        return 'Passport';
      case RenewalType.insurance:
        return 'Insurance';
      case RenewalType.licence:
        return 'Licence';
      case RenewalType.vehicle:
        return 'Vehicle';
      case RenewalType.warranty:
        return 'Warranty';
      case RenewalType.healthCheck:
        return 'Health check';
      case RenewalType.custom:
        return 'Custom';
    }
  }

  /// Whether this type needs the Custom short/medium/long lead-time
  /// selector (REQ-2.5).
  bool get usesCustomTier => this == RenewalType.custom;

  /// Whether this type needs the Health check recurrence-in-months field
  /// (REQ-1.1, REQ-2.4).
  bool get usesHealthRecurrence => this == RenewalType.healthCheck;

  /// Whether marking this type done offers a recurrence prompt at all.
  /// Warranty never does (REQ-9.3); every other type does, in one form or
  /// another (REQ-9.1/9.2/9.4).
  bool get hasRecurrencePrompt => this != RenewalType.warranty;

  static RenewalType fromName(String name) =>
      RenewalType.values.firstWhere((t) => t.name == name);
}
