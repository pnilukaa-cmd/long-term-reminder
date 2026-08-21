import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Health check's one-time "Not medical advice" note (REQ-1.2) and its
/// recurrence-in-months stepper (REQ-1.1). Deliberately styled as two
/// separate, plain widgets rather than one tinted callout — see
/// docs/design/02-v1-design.md §2a for why the *container* itself (not
/// just the copy) has to avoid reading as a recommendation.
class HealthCheckOneTimeNote extends StatelessWidget {
  const HealthCheckOneTimeNote({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sp3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppShapes.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not medical advice',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  "Screening and check-up intervals vary by person, so this app doesn't set one for you. "
                  "Pick whatever interval works for you below — you can change it anytime, the same way "
                  "you would any other reminder here.",
                  style: TextStyle(fontSize: 12, height: 1.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onDismiss,
            child: Text('Got it', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// REQ-1.1's plain stepper — same neutral container/weight as Label/Due
/// date, never the tinted `ladder-preview` treatment.
class HealthRecurrenceStepper extends StatelessWidget {
  const HealthRecurrenceStepper({super.key, required this.months, required this.onChanged});

  final int months;
  final ValueChanged<int> onChanged;

  static const int minMonths = 1;
  static const int maxMonths = 120; // sane cap — neither source doc specifies an upper bound (REQ-1.1)

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppShapes.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('months', style: TextStyle(fontSize: 14.5, color: scheme.onSurface)),
              Row(
                children: [
                  _StepButton(icon: Icons.remove, onTap: months > minMonths ? () => onChanged(months - 1) : null),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '$months',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StepButton(icon: Icons.add, onTap: months < maxMonths ? () => onChanged(months + 1) : null),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Your call — change this any time. Not a recommendation, just your own setting.',
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: onTap == null ? scheme.outline : scheme.onSurface),
      ),
    );
  }
}
