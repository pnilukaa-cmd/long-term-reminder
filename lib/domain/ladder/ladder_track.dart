import '../models/custom_tier.dart';
import '../models/date_math.dart';
import '../models/renewal_type.dart';
import 'ladder_calculator.dart';

/// What kind of marker a [LadderTrackEntry] represents on item detail's
/// horizontal ladder-track visualization
/// (`docs/design/mockups/03-item-detail.html`'s `.track`) — the app's core
/// differentiator made visible, per the developer task brief.
enum LadderTrackEntryKind { stage, today, due }

/// One dated marker on the track — a ladder stage, the "today" divider, or
/// the due-date marker itself.
class LadderTrackEntry {
  const LadderTrackEntry({
    required this.kind,
    required this.label,
    required this.date,
    required this.fired,
    this.isNext = false,
  });

  final LadderTrackEntryKind kind;

  /// "6mo" / "1wk" / "30d" for a stage, "Today" / "Due" for the other two
  /// kinds.
  final String label;

  final DateTime date;

  /// Stage: this stage's date has already passed relative to "now" (same
  /// `fired` semantics as [LadderStageInstance]). Due: the due date itself
  /// has passed (the item is overdue). Today: always false, unused.
  final bool fired;

  /// True only for the single stage that is the *next* one to fire — the
  /// mockup's `.t-dot.next` treatment (`primaryContainer`, not yet fired).
  /// Never true for `today`/`due`.
  final bool isNext;
}

/// Builds the ordered entry list item detail's ladder track renders — pure
/// and independent of the UI layer, so it's directly unit testable without
/// a device, per the developer task brief's instruction to test "the
/// undo-last-completion revert logic and any pure helpers" honestly.
///
/// **Paywall/billing gating is explicitly out of scope for this slice**
/// (developer task brief) — this always builds the *full paid* ladder,
/// unlocked, for every item, exactly like [LadderTables]/[LadderCalculator]
/// already do everywhere else in this codebase (see [LadderTables]'s own
/// class doc). The seam for a future entitlement check is here, deliberately
/// left clean: a paywall slice would gate *which* of these entries render
/// as locked (the greyed-marker treatment REQ-3.2/design doc §5 describes
/// for free-tier items), layered on as a rendering concern in the widget
/// that consumes this list — this function stays "what stages exist and
/// their dates," the same separation [LadderTables] already draws between
/// the paid ladder and the free single reminder.
class LadderTrack {
  const LadderTrack._();

  static List<LadderTrackEntry> build({
    required RenewalType type,
    required DateTime dueDate,
    required DateTime now,
    CustomTier? customTier,
  }) {
    final today = dateOnly(now);
    final due = dateOnly(dueDate);
    final overdue = !due.isAfter(today);

    final stages = LadderCalculator.paidLadderInstances(
      type: type,
      dueDate: dueDate,
      now: now,
      customTier: customTier,
    );
    final nextStage = LadderCalculator.nextUnfiredStage(stages);

    final entries = <LadderTrackEntry>[];
    // Once overdue, there's nothing left to count down to — the "Today"
    // divider only makes sense pre-due, so it's simply never inserted.
    var todayInserted = overdue;

    for (final stage in stages) {
      // Stages are ordered earliest-calendar-date-first (furthest lead
      // time first — e.g. 6mo/3mo/1mo/1wk for Passport), so walking the
      // list in order and inserting "Today" right before the first stage
      // whose date hasn't passed yet places it in exactly the right
      // chronological slot, whether that's before the very first stage
      // (a far-future item, nothing fired yet) or between two stages (some
      // fired, some still ahead).
      if (!todayInserted && !stage.date.isBefore(today)) {
        entries.add(LadderTrackEntry(kind: LadderTrackEntryKind.today, label: 'Today', date: today, fired: false));
        todayInserted = true;
      }
      entries.add(
        LadderTrackEntry(
          kind: LadderTrackEntryKind.stage,
          label: stage.offset.shortLabel,
          date: stage.date,
          fired: stage.fired,
          isNext: identical(stage, nextStage),
        ),
      );
    }
    // Every stage had already fired (all dates before today) — "Today"
    // belongs between the last fired stage and the due marker.
    if (!todayInserted) {
      entries.add(LadderTrackEntry(kind: LadderTrackEntryKind.today, label: 'Today', date: today, fired: false));
    }

    entries.add(LadderTrackEntry(kind: LadderTrackEntryKind.due, label: 'Due', date: due, fired: overdue));
    return entries;
  }
}
