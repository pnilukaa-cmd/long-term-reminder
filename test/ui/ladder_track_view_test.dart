// REQ-3.2/5.2's free-tier locked-stage rendering — "gate the rendering,
// not the data the helper produces" (developer task brief). Covers the
// widget-level half of that seam; `ladder_track_test.dart` covers the
// pure `LadderTrack.build` half.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/ladder/ladder_tables.dart';
import 'package:long_term_reminder/domain/ladder/ladder_track.dart';
import 'package:long_term_reminder/domain/models/ladder_offset.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/detail/widgets/ladder_track_view.dart';

void main() {
  // Vehicle, due 6 Jul 2027, "now" 20 Jun 2027 — the 30-day stage (6 Jun)
  // has already passed; 14-day (22 Jun) and 3-day (3 Jul) haven't. Free
  // reminder is the 14-day stage.
  final entries = LadderTrack.build(
    type: RenewalType.vehicle,
    dueDate: DateTime(2027, 7, 6),
    now: DateTime(2027, 6, 20),
  );
  final freeOffset = LadderTables.freeReminderOffset(RenewalType.vehicle);

  Widget buildView({required List<LadderTrackEntry> entries, required LadderOffset? freeOffset}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: LadderTrackView(entries: entries, freeOffset: freeOffset)),
    );
  }

  testWidgets('paid tier (freeOffset null) renders every stage unlocked, including the past one as fired', (
    tester,
  ) async {
    await tester.pumpWidget(buildView(entries: entries, freeOffset: null));

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'the already-passed 30-day stage reads as fired');
  });

  testWidgets('free tier locks every stage except the one matching freeReminderOffset', (tester) async {
    await tester.pumpWidget(buildView(entries: entries, freeOffset: freeOffset));

    // Two locked stages (30-day, 3-day); the 14-day free stage stays
    // unlocked and renders with its normal (next/upcoming) treatment.
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    // The 30-day stage's date has already passed, but because it's
    // locked it must never read as "fired" (checkmark) — it was never
    // actually scheduled for a free-tier user.
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
