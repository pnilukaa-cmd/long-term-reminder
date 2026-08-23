// Pure, device-free tests for item detail's ladder-track visualization
// (`lib/domain/ladder/ladder_track.dart`) — the developer task brief's own
// instruction to test "any pure helpers" honestly, without pretending a
// widget test can run without a device/toolchain in this environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/ladder/ladder_tables.dart';
import 'package:long_term_reminder/domain/ladder/ladder_track.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';

void main() {
  group('LadderTrack.build — Today marker placement', () {
    test('a far-future item places Today before the first (furthest-out) stage', () {
      // Vehicle: 30/14/3 days before. Due 6 Jul 2027, "now" 1 Jan 2027 —
      // every stage is still ahead.
      final entries = LadderTrack.build(
        type: RenewalType.vehicle,
        dueDate: DateTime(2027, 7, 6),
        now: DateTime(2027, 1, 1),
      );
      expect(entries.first.kind, LadderTrackEntryKind.today);
      expect(entries[1].kind, LadderTrackEntryKind.stage);
      expect(entries[1].fired, isFalse);
      expect(entries.last.kind, LadderTrackEntryKind.due);
      expect(entries.last.fired, isFalse);
    });

    test('Today sits between a fired stage and the next unfired one', () {
      // Vehicle due 6 Jul 2027: 30-day stage (Jun 6) has passed relative
      // to "now" (Jun 20); 14-day (Jun 22) and 3-day (Jul 3) have not.
      final entries = LadderTrack.build(
        type: RenewalType.vehicle,
        dueDate: DateTime(2027, 7, 6),
        now: DateTime(2027, 6, 20),
      );
      final kinds = entries.map((e) => e.kind).toList();
      // stage(fired) -> today -> stage(unfired) -> stage(unfired) -> due
      expect(kinds, [
        LadderTrackEntryKind.stage,
        LadderTrackEntryKind.today,
        LadderTrackEntryKind.stage,
        LadderTrackEntryKind.stage,
        LadderTrackEntryKind.due,
      ]);
      expect(entries[0].fired, isTrue);
      expect(entries[2].fired, isFalse);
      expect(entries[2].isNext, isTrue, reason: 'the first unfired stage is the "next" one');
      expect(entries[3].isNext, isFalse);
    });

    test('once every stage has fired, Today sits between the last stage and Due', () {
      final entries = LadderTrack.build(
        type: RenewalType.vehicle,
        dueDate: DateTime(2027, 7, 6),
        now: DateTime(2027, 7, 5), // every pre-due stage is in the past
      );
      final kinds = entries.map((e) => e.kind).toList();
      expect(kinds.last, LadderTrackEntryKind.due);
      expect(kinds[kinds.length - 2], LadderTrackEntryKind.today);
      expect(entries.every((e) => e.kind != LadderTrackEntryKind.stage || e.fired), isTrue);
    });

    test('an overdue item never gets a Today marker, and every stage plus Due reads as fired', () {
      final entries = LadderTrack.build(
        type: RenewalType.vehicle,
        dueDate: DateTime(2027, 1, 1),
        now: DateTime(2027, 3, 1), // 2 months overdue
      );
      expect(entries.any((e) => e.kind == LadderTrackEntryKind.today), isFalse);
      expect(entries.where((e) => e.kind == LadderTrackEntryKind.stage).every((e) => e.fired), isTrue);
      expect(entries.last.kind, LadderTrackEntryKind.due);
      expect(entries.last.fired, isTrue);
    });

    test('a due-today item counts as overdue for the track too, matching StatusCalculator\'s boundary', () {
      final entries = LadderTrack.build(
        type: RenewalType.warranty,
        dueDate: DateTime(2027, 1, 1),
        now: DateTime(2027, 1, 1),
      );
      expect(entries.any((e) => e.kind == LadderTrackEntryKind.today), isFalse);
      expect(entries.last.fired, isTrue);
    });
  });

  group('LadderTrack.build — stage labels and dates', () {
    test('Passport stage labels use the compact month/week form', () {
      final entries = LadderTrack.build(
        type: RenewalType.passport,
        dueDate: DateTime(2026, 12, 12),
        now: DateTime(2026, 8, 20),
      );
      final stageLabels = entries.where((e) => e.kind == LadderTrackEntryKind.stage).map((e) => e.label).toList();
      expect(stageLabels, ['6mo', '3mo', '1mo', '1wk']);
    });

    test('the Due entry date always equals the due date itself', () {
      final entries = LadderTrack.build(
        type: RenewalType.insurance,
        dueDate: DateTime(2027, 3, 21),
        now: DateTime(2027, 1, 1),
      );
      expect(entries.last.date, DateTime(2027, 3, 21));
    });
  });

  group('LadderTrack.build — offset carried through (developer task brief §5, the paywall-gating seam)', () {
    test(
      'always builds the full paid track regardless of entitlement — LadderTrack itself has no gating concept',
      () {
        // Vehicle: 30/14/3 days before — the full paid ladder, always.
        final entries = LadderTrack.build(
          type: RenewalType.vehicle,
          dueDate: DateTime(2027, 7, 6),
          now: DateTime(2027, 1, 1),
        );
        final stageOffsets = entries.where((e) => e.kind == LadderTrackEntryKind.stage).map((e) => e.offset).toList();
        expect(stageOffsets, LadderTables.paidLadderStages(RenewalType.vehicle));
      },
    );

    test('every stage entry carries its offset; today/due entries carry none', () {
      final entries = LadderTrack.build(
        type: RenewalType.warranty,
        dueDate: DateTime(2027, 6, 1),
        now: DateTime(2027, 1, 1),
      );
      for (final entry in entries) {
        if (entry.kind == LadderTrackEntryKind.stage) {
          expect(entry.offset, isNotNull);
        } else {
          expect(entry.offset, isNull);
        }
      }
    });
  });
}
