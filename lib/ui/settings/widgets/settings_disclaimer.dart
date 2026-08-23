import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// REQ-1.4 — the full legal + medical disclaimer, business-analyst's final
/// copy (`docs/requirements/03-v1-acceptance-criteria.md` §2), used
/// **verbatim**. Do not paraphrase, shorten, or "improve" this text — it
/// was written deliberately, including its word choices, and REQ-1.3's
/// copy-governance rule applies to any future edits here too.
///
/// This replaces `06-settings-privacy.html` panel p3's placeholder
/// `.disclaimer` paragraph, which that mockup itself flags as superseded
/// (see the developer task brief's read-first list). Rendered as short,
/// separate paragraphs rather than one dense block, per REQ-1.4's own
/// stated instruction that "a disclaimer nobody reads protects nobody."
///
/// The force-stop paragraph specifically was rewritten by business-analyst
/// on 2026-08-23 to name the mechanism plainly (per
/// `docs/technical/04-scheduling-and-stack.md` §2's finding) rather than
/// the vaguer "notifications can be delayed or blocked" language it
/// replaces — this is the one paragraph developer should be most careful
/// never to accidentally soften in a future edit.
class SettingsDisclaimer extends StatelessWidget {
  const SettingsDisclaimer({super.key});

  static const List<String> _paragraphs = [
    'This app reminds you about dates and intervals you set yourself. '
        "It doesn't verify official requirements and it isn't medical guidance — it's a personal reminder tool.",
    'For anything with legal or financial consequences — insurance, vehicle registration, professional licensing, '
        'and similar — check the actual requirements with the relevant authority or provider. Rules change and '
        "this app doesn't track them.",
    'For Health check reminders, the interval is entirely yours (or your healthcare provider\'s) to set. '
        'This app just repeats whatever number you chose.',
    'If you force-stop this app — or your phone\'s battery manager does it for you — Android cancels every '
        "reminder that was waiting to fire, and none of them come back until you open the app again. That's "
        "Android's own design for a force-stopped app, not a bug we can fix from here. Ordinary battery-saving "
        'settings can also delay a reminder without cancelling it, even without a force-stop.',
    "Whether or not a reminder arrives, you're still responsible for the renewal. Treat this as a memory aid, "
        'not a compliance system.',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not legal, financial, or medical advice',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
          ),
          for (final paragraph in _paragraphs) ...[
            const SizedBox(height: AppSpacing.sp2),
            Text(
              paragraph,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
