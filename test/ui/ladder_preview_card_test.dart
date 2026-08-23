// REQ-2.3's gating clause: "free tier shows only its single tuned
// reminder." Tested directly against the widget (rather than through the
// full Add/Edit flow, which would require driving the native date picker
// just to get this card to render at all) — [LadderPreviewCard] only
// needs a type/tier/entitlement triple, not a due date, to decide what to
// show.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/theme/app_theme.dart';
import 'package:long_term_reminder/ui/add_edit/widgets/ladder_preview_card.dart';

void main() {
  Widget buildCard({required bool isEntitled, RenewalType type = RenewalType.vehicle}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: LadderPreviewCard(type: type, isEntitled: isEntitled)),
    );
  }

  testWidgets('free tier shows exactly one stage chip and the single-reminder copy', (tester) async {
    await tester.pumpWidget(buildCard(isEntitled: false));

    // Vehicle's free reminder is a single "14 days before" stage.
    expect(find.text('14 days before'), findsOneWidget);
    expect(find.text('30 days before'), findsNothing, reason: "the paid ladder's first stage must not leak in");
    expect(find.text('3 days before'), findsNothing);
    expect(find.textContaining("You'll get this one reminder"), findsOneWidget);
    expect(find.text('Reminder scheduled (free plan)'), findsOneWidget);
  });

  testWidgets('paid tier shows the full multi-stage ladder', (tester) async {
    await tester.pumpWidget(buildCard(isEntitled: true));

    expect(find.text('30 days before'), findsOneWidget);
    expect(find.text('14 days before'), findsOneWidget);
    expect(find.text('3 days before'), findsOneWidget);
    expect(find.text('Reminders scheduled'), findsOneWidget);
  });
}
