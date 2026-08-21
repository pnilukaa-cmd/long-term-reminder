import 'package:flutter/material.dart';

import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_type.dart';
import '../../domain/recurrence/recurrence_calculator.dart';
import '../../theme/app_dimens.dart';

/// Result of the mark-done recurrence flow. [confirmed] is false when the
/// user backed out of a sheet/dialog without choosing anything — callers
/// should treat that as "do nothing at all", not "mark done with no next
/// cycle" (those are different outcomes; the latter is a deliberate
/// choice — Warranty, or an explicit "No" to Custom's repeat prompt).
class MarkDoneOutcome {
  const MarkDoneOutcome({required this.confirmed, this.nextDueDate});

  final bool confirmed;

  /// Null means "no next cycle" (Warranty, or Custom's "No" answer) when
  /// [confirmed] is true. Ignored when [confirmed] is false.
  final DateTime? nextDueDate;

  static const cancelled = MarkDoneOutcome(confirmed: false);
}

/// Drives the whole mark-done recurrence decision for [item], per REQ-9:
/// - Warranty (REQ-9.3): no UI at all, resolves immediately with no next
///   due date.
/// - Insurance/Vehicle/Licence/Passport/Health check (REQ-9.1/9.2): a
///   bottom sheet with a one-tap smart default plus a manual date-picker
///   fallback.
/// - Custom (REQ-9.4): a yes/no "does this repeat?" prompt first; "yes"
///   leads straight to the manual date picker (no smart default exists
///   for Custom).
Future<MarkDoneOutcome> showMarkDoneFlow(BuildContext context, Renewal item) async {
  final kind = RecurrenceCalculator.uiKindFor(item.type);

  switch (kind) {
    case RecurrenceUiKind.none:
      return const MarkDoneOutcome(confirmed: true, nextDueDate: null);

    case RecurrenceUiKind.smartDefaultWithManualOption:
      return _showSmartDefaultSheet(context, item);

    case RecurrenceUiKind.yesNoThenManualOnly:
      return _showRepeatsPrompt(context, item);
  }
}

Future<MarkDoneOutcome> _showSmartDefaultSheet(BuildContext context, Renewal item) async {
  final smartDefault = RecurrenceCalculator.smartDefaultNextDueDate(
    type: item.type,
    dueDate: item.dueDate,
    healthRecurrenceMonths: item.healthRecurrenceMonths,
  )!;
  final smartLabel = RecurrenceCalculator.smartDefaultLabel(
    type: item.type,
    healthRecurrenceMonths: item.healthRecurrenceMonths,
  );

  final result = await showModalBottomSheet<_SheetChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RecurrenceSheet(
      title: "Nice — when's the next one due?",
      subtitle: item.type == RenewalType.healthCheck
          ? "This uses your own stored interval, not a fresh suggestion."
          : null,
      primaryTitle: smartLabel,
      primarySubtitle: '${_longDate(smartDefault)}, from your due date',
      primaryIcon: Icons.add,
      secondaryTitle: 'Pick a different date',
      secondarySubtitle: 'Opens the date picker',
      secondaryIcon: Icons.calendar_month_outlined,
    ),
  );

  if (result == null) return MarkDoneOutcome.cancelled;
  if (result == _SheetChoice.primary) {
    return MarkDoneOutcome(confirmed: true, nextDueDate: smartDefault);
  }

  // Manual date option — REQ-9.2: whatever is entered is used exactly as
  // entered, no validation against the type's "typical" cycle length.
  if (!context.mounted) return MarkDoneOutcome.cancelled;
  final picked = await _pickManualDate(context, initial: smartDefault);
  if (picked == null) return MarkDoneOutcome.cancelled;
  return MarkDoneOutcome(confirmed: true, nextDueDate: picked);
}

Future<MarkDoneOutcome> _showRepeatsPrompt(BuildContext context, Renewal item) async {
  final result = await showModalBottomSheet<_SheetChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _RecurrenceSheet(
      title: 'Does this repeat?',
      subtitle: "We don't know this one's cadence, so there's no suggested date — just yours.",
      primaryTitle: 'Yes — pick the next date',
      primarySubtitle: 'Opens the date picker',
      primaryIcon: Icons.calendar_month_outlined,
      secondaryTitle: "No — it's a one-off",
      secondarySubtitle: 'Moves straight to Done, nothing more to track',
      secondaryIcon: Icons.check,
    ),
  );

  if (result == null) return MarkDoneOutcome.cancelled;
  if (result == _SheetChoice.secondary) {
    return const MarkDoneOutcome(confirmed: true, nextDueDate: null);
  }

  if (!context.mounted) return MarkDoneOutcome.cancelled;
  final picked = await _pickManualDate(context, initial: item.dueDate);
  if (picked == null) return MarkDoneOutcome.cancelled;
  return MarkDoneOutcome(confirmed: true, nextDueDate: picked);
}

Future<DateTime?> _pickManualDate(BuildContext context, {required DateTime initial}) {
  final now = DateTime.now();
  final firstDate = initial.isBefore(now) ? initial : now;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(firstDate.year - 1),
    lastDate: DateTime(now.year + 50),
  );
}

String _longDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

enum _SheetChoice { primary, secondary }

class _RecurrenceSheet extends StatelessWidget {
  const _RecurrenceSheet({
    required this.title,
    this.subtitle,
    required this.primaryTitle,
    required this.primarySubtitle,
    required this.primaryIcon,
    required this.secondaryTitle,
    required this.secondarySubtitle,
    required this.secondaryIcon,
  });

  final String title;
  final String? subtitle;
  final String primaryTitle;
  final String primarySubtitle;
  final IconData primaryIcon;
  final String secondaryTitle;
  final String secondarySubtitle;
  final IconData secondaryIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, 10, AppSpacing.sp4, AppSpacing.sp5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.45)),
            ],
            const SizedBox(height: AppSpacing.sp4),
            _SheetOption(
              title: primaryTitle,
              subtitle: primarySubtitle,
              icon: primaryIcon,
              primary: true,
              onTap: () => Navigator.of(context).pop(_SheetChoice.primary),
            ),
            const SizedBox(height: 10),
            _SheetOption(
              title: secondaryTitle,
              subtitle: secondarySubtitle,
              icon: secondaryIcon,
              primary: false,
              onTap: () => Navigator.of(context).pop(_SheetChoice.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = primary ? scheme.primaryContainer : Colors.transparent;
    final borderColor = primary ? scheme.primary : scheme.outlineVariant;
    final iconBackground = primary ? Colors.white.withValues(alpha: .5) : scheme.surfaceContainerHigh;
    final iconColor = primary ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final titleColor = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    final subtitleColor = primary ? scheme.onPrimaryContainer.withValues(alpha: .85) : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppShapes.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: titleColor)),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: subtitleColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
