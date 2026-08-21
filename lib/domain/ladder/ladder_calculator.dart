import '../models/custom_tier.dart';
import '../models/date_math.dart';
import '../models/ladder_offset.dart';
import '../models/renewal_type.dart';
import 'ladder_tables.dart';

/// One concrete, dated instance of a ladder stage for a specific item.
class LadderStageInstance {
  const LadderStageInstance({
    required this.offset,
    required this.date,
    required this.fired,
  });

  final LadderOffset offset;
  final DateTime date;

  /// True once [date] has passed relative to "now" (day granularity —
  /// see [dateOnly]). Design doc's own framing: every acceptance criterion
  /// here is written against same-day delivery, never an hour/minute.
  final bool fired;

  String get label => offset.label;
}

/// Computes ladder stage dates for a single item and answers the small set
/// of derived questions the list/detail UI needs (next stage, progress
/// dots). Pure, side-effect-free, and the thing this slice's unit tests
/// exercise directly.
class LadderCalculator {
  const LadderCalculator._();

  /// REQ-3.1's stage list, dated against [dueDate] and evaluated against
  /// [now]. Stages already in the past relative to [now] are *silently
  /// skipped* from the result — the design's explicit rule is that a stage
  /// whose date has already passed by the time the item is created/edited
  /// is not fired retroactively (REQ-3.1, REQ-17.1) — it simply never
  /// appears as a pending stage. What ships to the caller instead has
  /// `fired: false` for genuinely-future stages and omits the rest.
  ///
  /// This function does *not* decide free/paid gating — callers pass the
  /// already-resolved offset list in (see [LadderTables]).
  static List<LadderStageInstance> instancesFor({
    required List<LadderOffset> offsets,
    required DateTime dueDate,
    required DateTime now,
  }) {
    final today = dateOnly(now);
    return offsets
        .map((offset) {
          final date = dateOnly(offset.dateBefore(dueDate));
          final fired = !date.isAfter(today);
          return LadderStageInstance(offset: offset, date: date, fired: fired);
        })
        // A stage whose date is before *today* AND before item creation is
        // still shown (as already-fired) so the UI's stage-dots/progress
        // reads correctly — REQ-3.1 only says *notifications* aren't fired
        // retroactively, not that the stage disappears from the ladder
        // entirely. See REQ-17.1 for the fully-past-due case.
        .toList(growable: false);
  }

  /// Convenience wrapper that resolves the full paid ladder for [type]
  /// (honouring [customTier] when relevant) and dates it against
  /// [dueDate]/[now].
  static List<LadderStageInstance> paidLadderInstances({
    required RenewalType type,
    required DateTime dueDate,
    required DateTime now,
    CustomTier? customTier,
  }) {
    final offsets = LadderTables.paidLadderStages(type, customTier: customTier);
    return instancesFor(offsets: offsets, dueDate: dueDate, now: now);
  }

  /// The next stage that hasn't fired yet, or null if every stage has
  /// already fired (item is in its final pre-due window, or the due date
  /// itself has passed).
  static LadderStageInstance? nextUnfiredStage(List<LadderStageInstance> stages) {
    for (final stage in stages) {
      if (!stage.fired) return stage;
    }
    return null;
  }

  /// The stage closest to the due date (last in furthest-to-closest
  /// ordering) — used by [status_calculator] to decide the Due soon
  /// threshold per REQ-4.2's BA default.
  static LadderStageInstance? closestToDueStage(List<LadderStageInstance> stages) {
    if (stages.isEmpty) return null;
    return stages.last;
  }
}
