import 'package:flutter/material.dart';

import '../../domain/models/renewal_status.dart';
import '../../theme/app_semantic_colors.dart';

/// Status is encoded on four channels at once — shape, icon glyph, color,
/// and text label — not color alone, per design doc §6's accessibility
/// reasoning (colorblind-safe, and status should read in form as well as
/// color).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 20});

  final RenewalStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    switch (status) {
      case RenewalStatus.upcoming:
        return _dot(
          size: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant, width: 2),
          ),
          icon: Icons.schedule_outlined,
          iconColor: scheme.onSurfaceVariant,
        );
      case RenewalStatus.dueSoon:
        return _dot(
          size: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: semantic.warningContainer),
          icon: Icons.schedule,
          iconColor: semantic.onWarningContainer,
        );
      case RenewalStatus.overdue:
        return _dot(
          size: size,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            // Pennant/flag notch: a small cut corner distinguishes this
            // shape from a plain filled circle, matching the mockup's
            // `border-radius: 999px 999px 999px 4px`.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(999),
              topRight: Radius.circular(999),
              bottomRight: Radius.circular(999),
              bottomLeft: Radius.circular(4),
            ),
          ),
          icon: Icons.priority_high,
          iconColor: scheme.onErrorContainer,
        );
      case RenewalStatus.done:
        return _dot(
          size: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: semantic.successContainer),
          icon: Icons.check,
          iconColor: semantic.onSuccessContainer,
        );
    }
  }

  Widget _dot({
    required double size,
    required BoxDecoration decoration,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: iconColor),
    );
  }
}

/// The pill-shaped status/next-stage chip next to [StatusDot] on a card.
class StatusChipView extends StatelessWidget {
  const StatusChipView({super.key, required this.label, required this.status});

  final String label;
  final RenewalStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    Color background;
    Color foreground;
    switch (status) {
      case RenewalStatus.overdue:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
      case RenewalStatus.dueSoon:
        background = semantic.warningContainer;
        foreground = semantic.onWarningContainer;
      case RenewalStatus.upcoming:
      case RenewalStatus.done:
        background = scheme.surfaceContainerHigh;
        foreground = scheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}
