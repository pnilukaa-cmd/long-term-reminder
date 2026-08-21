/// The three lead-time profiles available for the Custom type, per
/// docs/design/02-v1-design.md §2b and REQ-2.5. `name` is persisted to the
/// database — do not rename existing values without a migration.
enum CustomTier {
  short,
  medium,
  long;

  /// Medium is the existing fixed default — nothing regresses for a user
  /// who never touches the selector (REQ-2.5).
  static const CustomTier defaultTier = CustomTier.medium;

  String get displayName {
    switch (this) {
      case CustomTier.short:
        return 'Short';
      case CustomTier.medium:
        return 'Medium';
      case CustomTier.long:
        return 'Long';
    }
  }

  static CustomTier fromName(String name) =>
      CustomTier.values.firstWhere((t) => t.name == name);
}
