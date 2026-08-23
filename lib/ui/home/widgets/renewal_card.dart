import 'package:flutter/material.dart';

import '../../../domain/format/relative_date.dart';
import '../../../domain/ladder/ladder_calculator.dart';
import '../../../domain/models/renewal.dart';
import '../../../domain/models/renewal_status.dart';
import '../../../domain/models/renewal_type.dart';
import '../../../theme/app_dimens.dart';
import '../../common/status_visuals.dart';
import '../../common/type_badge.dart';

/// One row on the home list, matching `.card` across
/// `docs/design/mockups/01-home-list.html`'s success-state panels,
/// including the long-press-revealed delete affordance (panel p6).
class RenewalCard extends StatelessWidget {
  const RenewalCard({
    super.key,
    required this.item,
    required this.status,
    required this.now,
    required this.isRevealed,
    required this.isDimmed,
    required this.onQuickDone,
    required this.onLongPress,
    required this.onTapWhileRevealed,
    required this.onDelete,
    required this.onOpenDetail,
  });

  final Renewal item;
  final RenewalStatus status;
  final DateTime now;

  /// True if long-press has revealed this specific card's delete action
  /// (REQ-5.4/§0.2 default, design doc §4b).
  final bool isRevealed;

  /// True if a *different* card is currently revealed — dims this card to
  /// ~40% opacity per the mockup's contextual-selection cue.
  final bool isDimmed;

  final VoidCallback onQuickDone;
  final VoidCallback onLongPress;
  final VoidCallback onTapWhileRevealed;
  final VoidCallback onDelete;

  /// Design doc §3/§5: item detail is reached by tapping a card. Only
  /// fires on a plain tap while the card is at rest — while revealed
  /// (long-press contextual-selection state), a tap dismisses the reveal
  /// instead ([onTapWhileRevealed]), matching the existing gesture rule
  /// rather than adding a second, competing tap target.
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = status == RenewalStatus.done;

    // Design doc §7a's dark-theme elevation fix, applied where the card
    // color is actually consumed (this widget builds its own Container
    // rather than a Card, so `ThemeData.cardTheme` alone has no effect
    // here — see app_theme.dart's cardTheme doc comment for the same fix
    // at the theme level, kept for consistency/future Card() usage).
    // Light: unchanged (white resting, white-with-border-and-shadow
    // held). Dark: `surfaceContainerLowest` (tone 4) sits *below* the
    // tone-6 scaffold, so resting there renders as a recessed hole; rest
    // on `surfaceContainer` (tone 12) instead, and held/long-pressed on
    // `surfaceContainerHigh` (tone 17) — shadow alone doesn't read on
    // near-black, the tone step has to carry it.
    final isDark = scheme.brightness == Brightness.dark;
    final cardColor = isDark
        ? (isRevealed ? scheme.surfaceContainerHigh : scheme.surfaceContainer)
        : scheme.surfaceContainerLowest;

    final card = AnimatedOpacity(
      opacity: isDone ? .55 : (isDimmed ? .4 : 1),
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.sp4),
        margin: const EdgeInsets.only(bottom: AppSpacing.sp3),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppShapes.lg),
          border: isRevealed ? Border.all(color: scheme.primary, width: 2) : null,
          boxShadow: isRevealed
              ? [BoxShadow(color: scheme.primary.withValues(alpha: .28), blurRadius: 20, offset: const Offset(0, 6))]
              : [const BoxShadow(color: Color(0x0F1414A0), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypeBadge(type: item.type),
                const SizedBox(width: AppSpacing.sp3),
                Expanded(child: _CardBody(item: item, status: status, now: now)),
                // Quick-done only makes sense for not-yet-done items, but
                // long-press-reveal delete applies to *any* status,
                // including Done — a completed item stays visible until
                // the user deletes it themselves (REQ-9.3), so it must
                // stay deletable.
                if (!isDone || isRevealed) ...[
                  const SizedBox(width: AppSpacing.sp2),
                  if (isRevealed)
                    Column(
                      children: [
                        if (!isDone) ...[
                          _QuickIconButton(icon: Icons.check, onTap: onQuickDone),
                          const SizedBox(height: 8),
                        ],
                        _QuickIconButton(
                          icon: Icons.delete_outline,
                          onTap: onDelete,
                          background: scheme.errorContainer,
                          foreground: scheme.onErrorContainer,
                        ),
                      ],
                    )
                  else
                    _QuickIconButton(icon: Icons.check, onTap: onQuickDone),
                ],
              ],
            ),
            if (isRevealed)
              Positioned(
                top: -11,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    'Held',
                    style: TextStyle(color: scheme.onPrimary, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // `isDimmed` (a *different* card is revealed) must also route to
    // `onTapWhileRevealed`, not `onOpenDetail` — otherwise tapping any
    // other card while one is held would navigate away instead of
    // dismissing the reveal, since a non-null `onTap` here now always
    // competes with (and, being more nested, normally beats) the list's
    // own tap-anywhere-to-dismiss `GestureDetector` in the gesture arena.
    // Before `onOpenDetail` existed, a non-revealed card's `onTap` was
    // simply `null`, so no competing recognizer was ever registered and
    // the outer dismiss-handler won uncontested — this restores that
    // contextual-selection behaviour for the "at rest" case only.
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: (isRevealed || isDimmed) ? onTapWhileRevealed : onOpenDetail,
      child: card,
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.item, required this.status, required this.now});

  final Renewal item;
  final RenewalStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = status == RenewalStatus.done;

    final subtitle = isDone
        ? RelativeDateFormatter.doneLine(item.lastCompletedAt ?? item.updatedAt, null)
        : _dueLineWithTypeSuffix();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            StatusDot(status: status),
            const SizedBox(width: 8),
            Flexible(child: _trailingChip(context)),
          ],
        ),
        if (!isDone && status != RenewalStatus.overdue) ...[
          const SizedBox(height: 6),
          _StageDots(item: item, now: now),
        ],
      ],
    );
  }

  String _dueLineWithTypeSuffix() {
    final base = RelativeDateFormatter.dueLine(item.dueDate, now);
    if (item.type == RenewalType.healthCheck && item.healthRecurrenceMonths != null) {
      return '$base · every ${item.healthRecurrenceMonths} months';
    }
    if (item.type == RenewalType.custom && item.customTier != null) {
      return '$base · ${item.customTier!.displayName} lead time';
    }
    return base;
  }

  Widget _trailingChip(BuildContext context) {
    if (status == RenewalStatus.overdue) {
      return StatusChipView(label: 'Overdue', status: status);
    }
    if (status == RenewalStatus.done) {
      return StatusChipView(label: 'Done', status: status);
    }
    final stages = LadderCalculator.paidLadderInstances(
      type: item.type,
      dueDate: item.dueDate,
      now: now,
      customTier: item.customTier,
    );
    final next = LadderCalculator.nextUnfiredStage(stages);
    final label = next != null ? 'Next: ${next.label}' : 'Final warning sent';
    return StatusChipView(label: label, status: status);
  }
}

class _StageDots extends StatelessWidget {
  const _StageDots({required this.item, required this.now});

  final Renewal item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stages = LadderCalculator.paidLadderInstances(
      type: item.type,
      dueDate: item.dueDate,
      now: now,
      customTier: item.customTier,
    );
    return Row(
      children: [
        for (final stage in stages)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stage.fired ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickIconButton extends StatelessWidget {
  const _QuickIconButton({required this.icon, required this.onTap, this.background, this.foreground});

  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: background ?? scheme.surfaceContainerHigh, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: foreground ?? scheme.onSurfaceVariant),
      ),
    );
  }
}
