/// The four statuses a renewal item can be in, per
/// docs/requirements/03-v1-acceptance-criteria.md REQ-4.2 and
/// docs/design/02-v1-design.md §6.
enum RenewalStatus {
  overdue,
  dueSoon,
  upcoming,
  done;

  /// Section label used to group the list (order matches REQ-4.1's success
  /// state: Overdue / Due soon / Upcoming / Done).
  String get sectionLabel {
    switch (this) {
      case RenewalStatus.overdue:
        return 'Overdue';
      case RenewalStatus.dueSoon:
        return 'Due soon';
      case RenewalStatus.upcoming:
        return 'Upcoming';
      case RenewalStatus.done:
        return 'Done';
    }
  }

  /// Fixed section ordering for the list screen (REQ-4.1/REQ-4.2).
  static const List<RenewalStatus> sectionOrder = [
    RenewalStatus.overdue,
    RenewalStatus.dueSoon,
    RenewalStatus.upcoming,
    RenewalStatus.done,
  ];
}
