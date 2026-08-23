import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// REQ-9.5 / design doc §4's deferred recurrence decision: shown when a
/// `Mark done` notification action on a recurring item cancelled its
/// remaining nags but couldn't ask "when's it next due?" at the time (no
/// foreground UI existed at that moment). Deliberately **not** the tinted
/// `primary-container` ladder-preview style — this is a plain, neutral
/// banner (same reasoning as the Health check one-time note, design doc
/// §2a: a question the user needs to answer, not the app asserting
/// something) with a single clear action.
class DeferredRecurrenceBanner extends StatelessWidget {
  const DeferredRecurrenceBanner({super.key, required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You marked this done from a notification',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  "We cancelled the rest of this cycle's reminders — when's it next due?",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(onPressed: onChoose, child: const Text('Choose next due date')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
