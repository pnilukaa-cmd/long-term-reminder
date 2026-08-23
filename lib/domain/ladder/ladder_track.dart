import '../models/custom_tier.dart';
import '../models/date_math.dart';
import '../models/ladder_offset.dart';
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
    this.offset,
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

  /// The raw ladder offset this stage entry represents — set only for
  /// `kind == stage`, null for `today`/`due`. Carried through deliberately
  /// so a *caller* can decide free/paid locking (compare against
  /// [LadderTables.freeReminderOffset]) without this class needing any
  /// entitlement concept of its own — see this file's class doc on the
  /// gating seam. [LadderTrack.build] itself never changes shape based on
  /// entitlement; it always returns the full paid track, unlocked.
  final LadderOffset? offset;
}

/// Builds the ordered entry list item detail's ladder track renders — pure
/// and independent of the UI layer, so it's directly unit testable without
/// a device, per the developer task brief's instruction to test "the
/// undo-last-completion revert logic and any pure helpers" honestly.
///
/// **Deliberately entitlement-unaware.** [build] always returns the *full
/// paid* ladder, unlocked, for every item, exactly like
/// [LadderTables]/[LadderCalculator] do everywhere else in this codebase.
/// The billing slice gates *which* of these entries render as locked (the
/// greyed-marker treatment REQ-3.2/design doc §5 describes for free-tier
/// items) entirely in the widget that consumes this list —
/// `LadderTrackView`, via its `freeOffset` parameter, compares each
/// [LadderTrackEntry.offset] against [LadderTables.freeReminderOffset] — so
/// this function keeps meaning exactly one thing, "what stages exist and
/// their dates," the same separation [LadderTables] already draws between
/// the paid ladder and the free single reminder. See `LadderTrackView`'s
/// own doc comment for the gating half of this seam.
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
          offset: stage.offset,
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
