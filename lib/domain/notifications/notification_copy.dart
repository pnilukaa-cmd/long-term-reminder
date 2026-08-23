import '../format/relative_date.dart';
import '../models/ladder_offset.dart';
import '../models/renewal_type.dart';

/// Notification title/body copy, per REQ-11.3 and design doc §4/§6a.
///
/// REQ-15 ("not covered by this document") is explicit that only the
/// *pattern* plus a couple of worked examples were drafted by BA — the
/// remaining 7-types × 2-kinds combinations were left as "a copy-completion
/// pass... can reasonably be done alongside implementation rather than
/// blocking it." This class is that pass. It follows the stated template
/// and tone rules exactly (never blame language, never urgency-stacked on
/// top of the icon's own colour), but the exact per-type sentences below
/// are this developer's own drafting, not BA-authored copy — flagged in
/// the handoff as worth a look from business-analyst, not a silent
/// substitute for one.
class NotificationCopy {
  const NotificationCopy._();

  /// REQ-11.3: `"[Label] · due in [N] days"` (or type-appropriate
  /// phrasing — here, reusing [LadderOffset.label]'s own unit so a
  /// months-out stage reads "due in 6 months," not "due in 182 days").
  static String ladderStageTitle(String itemLabel, LadderOffset offset) {
    final phrase = offset.label.replaceFirst(' before', '');
    return '$itemLabel · due in $phrase';
  }

  /// Plain, matter-of-fact body — "[due date]. [type-appropriate action
  /// line]," matching `07-notifications.html` panel p1's worked example
  /// for Vehicle verbatim ("Jul 2. Worth booking this week if you
  /// haven't already.").
  static String ladderStageBody(RenewalType type, DateTime dueDate) {
    return '${RelativeDateFormatter.shortDate(dueDate)}. ${_ladderActionLine(type)}';
  }

  static String _ladderActionLine(RenewalType type) {
    switch (type) {
      case RenewalType.passport:
        return 'Processing can take weeks — worth starting soon.';
      case RenewalType.insurance:
        return "Worth comparing or renewing before this lapses.";
      case RenewalType.licence:
        return 'Check what renewal needs before this lapses.';
      case RenewalType.vehicle:
        return "Worth booking this week if you haven't already.";
      case RenewalType.warranty:
        return "Good to know while it's still covered.";
      case RenewalType.healthCheck:
        return 'Worth booking an appointment soon.';
      case RenewalType.custom:
        return 'Worth sorting soon.';
    }
  }

  /// REQ-11.3's overdue-nag template, matching `07-notifications.html`
  /// panel p2 exactly: `"[Label] — still open"` / collaborative,
  /// non-blame body. Kept generic across all seven types (as the one
  /// mocked example is) rather than type-varied — the tone rule matters
  /// more here than type-specific phrasing, and design doc §4 only
  /// specifies the generic pattern.
  static String overdueNagTitle(String itemLabel) => '$itemLabel — still open';

  static String overdueNagBody(DateTime dueDate, DateTime fireOn) {
    final line = RelativeDateFormatter.dueLine(dueDate, fireOn);
    return '$line. Still need to sort this?';
  }

  /// REQ-12.1's collapsed group summary — count-driven, specific to the
  /// items involved, never a generic "you have new notifications."
  static String groupSummaryTitle(int count) => '$count renewals need attention';

  /// `"Car insurance, MOT — Honda Civic +1 more"` — first two labels,
  /// truncated past two, matching panel p3 exactly.
  static String groupSummaryBody(List<String> itemLabels) {
    if (itemLabels.length <= 2) return itemLabels.join(', ');
    final shown = itemLabels.take(2).join(', ');
    final remaining = itemLabels.length - 2;
    return '$shown +$remaining more';
  }

  /// REQ-12.2's expanded per-line copy — `"MOT — Honda Civic · 3 days
  /// before"` / `"Car insurance · overdue"`.
  static String groupLineText({
    required String itemLabel,
    required bool isOverdue,
    LadderOffset? ladderOffset,
  }) {
    if (isOverdue) return '$itemLabel · overdue';
    final suffix = ladderOffset?.label ?? 'due soon';
    return '$itemLabel · $suffix';
  }
}
