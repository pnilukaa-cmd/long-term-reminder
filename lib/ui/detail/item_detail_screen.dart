import 'package:flutter/material.dart';

import '../../data/repository/entitlement_repository.dart';
import '../../data/repository/renewal_repository.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/format/relative_date.dart';
import '../../domain/ladder/ladder_tables.dart';
import '../../domain/ladder/ladder_track.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_status.dart';
import '../../domain/models/renewal_type.dart';
import '../../domain/status/status_calculator.dart';
import '../../services/billing/billing_gateway.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reconciliation_service.dart';
import '../../theme/app_dimens.dart';
import '../add_edit/add_edit_screen.dart';
import '../common/mark_done_sheet.dart';
import '../common/status_visuals.dart';
import '../common/type_badge.dart';
import '../common/undo_controller.dart';
import '../common/undo_toast.dart';
import '../paywall/paywall_screen.dart';
import 'widgets/deferred_recurrence_banner.dart';
import 'widgets/detail_loading_view.dart';
import 'widgets/detail_not_found_view.dart';
import 'widgets/ladder_track_view.dart';

/// Item detail — REQ-5, plus `Undo last completion` (scope doc §3d), the
/// deferred recurrence banner that closes REQ-9.5's notification gap, and
/// (this slice) the free/paid ladder-track gating from REQ-3.2/REQ-5.2 —
/// "gate the rendering, not the data the helper produces," per the
/// developer task brief; see `LadderTrackView`'s doc comment for exactly
/// how that seam works. Matches `docs/design/mockups/03-item-detail.html`.
/// Reachable by tapping a card on the home list.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.repository,
    required this.settingsRepository,
    required this.entitlementRepository,
    required this.billingGateway,
    required this.notificationService,
    required this.reconciliationService,
  });

  final int itemId;
  final RenewalRepository repository;
  final SettingsRepository settingsRepository;

  /// Drives the free/paid ladder-track rendering (REQ-3.2/5.2) via a live
  /// stream, the same way the item itself is driven off a live stream —
  /// a purchase completing while this screen is open updates the track
  /// immediately, no manual refresh.
  final EntitlementRepository entitlementRepository;

  /// Only threaded through to construct [PaywallScreen] when the unlock
  /// banner is tapped — this screen never calls it directly.
  final BillingGateway billingGateway;

  /// Only actually used if the user opens Edit — [AddEditScreen] requires
  /// it for the (edit-mode-inapplicable) first-item permission-priming
  /// path. Threaded through rather than re-fetched so this screen doesn't
  /// need its own separate handle on notification plumbing.
  final NotificationService notificationService;
  final ReconciliationService reconciliationService;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Stream<Renewal?> _itemStream = widget.repository.watchById(widget.itemId);

  late final UndoController _undoController = UndoController(
    widget.repository,
    // Same reasoning as HomeScreen's own wiring: reconcile promptly after
    // this screen's own commits (delete/mark-done/undo-last-completion),
    // rather than waiting for next launch/periodic pass.
    onCommitted: _handleCommitted,
  );

  /// Set right before scheduling a delete via [_undoController] so
  /// [_handleCommitted] knows to navigate back once it actually lands —
  /// there is nothing left on this single-item screen to show once its
  /// one item is genuinely gone. [UndoController.undo] never invokes
  /// `onCommitted` (see its own doc comment), so this only ever fires on a
  /// real commit, never on a reverted one.
  bool _pendingIsDelete = false;

  @override
  void dispose() {
    _undoController.dispose();
    super.dispose();
  }

  Future<void> _handleCommitted() async {
    await widget.reconciliationService.reconcile();
    if (_pendingIsDelete) {
      _pendingIsDelete = false;
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _handleDelete(Renewal item) async {
    // No `Navigator.pop()` here: `PopupMenuButton.onSelected` fires *after*
    // its own menu route has already popped itself (that's how
    // `showMenu`'s result plumbing works), so calling pop() again here
    // would incorrectly pop this whole screen instead.
    _pendingIsDelete = true;
    await _undoController.scheduleDelete(item);
  }

  Future<void> _handleMarkDone(Renewal item) async {
    final outcome = await showMarkDoneFlow(context, item);
    if (!outcome.confirmed) return;
    _pendingIsDelete = false;
    await _undoController.scheduleMarkDone(item, nextDueDate: outcome.nextDueDate);
  }

  Future<void> _handleUndoLastCompletion(Renewal item) async {
    final reverted = await widget.repository.undoLastCompletion(item.id);
    if (!reverted) return;
    await widget.reconciliationService.reconcile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completion undone.')));
  }

  Future<void> _openEdit(Renewal item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          repository: widget.repository,
          settingsRepository: widget.settingsRepository,
          entitlementRepository: widget.entitlementRepository,
          notificationService: widget.notificationService,
          reconciliationService: widget.reconciliationService,
          existingItem: item,
        ),
      ),
    );
  }

  /// REQ-3.2's inline unlock banner → the actual purchase screen. Design
  /// doc §5: the paywall's own pitch is deliberately short because the
  /// real pitch already happened here, on the ladder track.
  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          billingGateway: widget.billingGateway,
          entitlementRepository: widget.entitlementRepository,
          reconciliationService: widget.reconciliationService,
        ),
      ),
    );
  }

  /// Mirrors [UndoController.applyOverlay]'s mark-done branch directly
  /// (rather than routing through that list-oriented method, whose
  /// delete branch would incorrectly filter this single item out of its
  /// own detail screen while a delete is pending) — same optimistic-UI
  /// contract: the screen reflects a pending mark-done's effect
  /// immediately, without it having actually committed to the database
  /// yet, matching `03-item-detail.html` panel p7 (the item already shows
  /// `Done` alongside the toast, before the 6-second window lapses).
  Renewal _effective(Renewal item) {
    final pending = _undoController.pending;
    if (pending == null || pending.item.id != item.id || pending.type != PendingActionType.markDone) return item;
    final isTerminal = pending.nextDueDate == null;
    return item.copyWith(isDone: isTerminal, dueDate: pending.nextDueDate);
  }

  @override
  Widget build(BuildContext context) {
    // Entitlement drives only the ladder card's rendering (REQ-3.2/5.2) —
    // deliberately a separate, independent StreamBuilder rather than
    // merged into the item stream below, so a purchase/restore landing
    // while this screen is open updates the track without needing the
    // item's own row to change. Defaults to `false` (free/locked
    // rendering) for the brief instant before the first value arrives —
    // this is a local drift read, not a network call, so that gap is
    // negligible, and "briefly under-render what's unlocked" is the safe
    // direction to fail in over the reverse.
    return StreamBuilder<bool>(
      stream: widget.entitlementRepository.watchEntitled(),
      initialData: false,
      builder: (context, entitlementSnapshot) {
        final isEntitled = entitlementSnapshot.data ?? false;
        return _buildForEntitlement(context, isEntitled);
      },
    );
  }

  Widget _buildForEntitlement(BuildContext context, bool isEntitled) {
    return StreamBuilder<Renewal?>(
      stream: _itemStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const SafeArea(child: DetailLoadingView()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: SafeArea(child: DetailNotFoundView(onBack: () => Navigator.of(context).pop())),
          );
        }

        final rawItem = snapshot.data!;
        final item = _effective(rawItem);
        final now = DateTime.now();
        final status = StatusCalculator.computeStatus(
          type: item.type,
          dueDate: item.dueDate,
          isDone: item.isDone,
          now: now,
          customTier: item.customTier,
        );
        final pending = _undoController.pending;
        final showDeferredBanner =
            rawItem.pendingRecurrenceDecision && (pending == null || pending.item.id != rawItem.id);
        final isDone = status == RenewalStatus.done;

        return Scaffold(
          appBar: _DetailAppBar(
            item: item,
            onDelete: () => _handleDelete(item),
            onUndoLastCompletion: rawItem.hasUndoableCompletion ? () => _handleUndoLastCompletion(item) : null,
          ),
          // The toast is positioned at the *bottom of `body`*, not floated
          // over the whole Scaffold — since `bottomNavigationBar` is a
          // separate, non-overlapping Scaffold slot below `body`, this
          // naturally sits directly above the action bar with no manual
          // offset guessing, satisfying design doc §4a's "never covering
          // an actionable button" rule for free.
          body: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp2, AppSpacing.sp4, AppSpacing.sp7),
                  children: [
                    if (showDeferredBanner) DeferredRecurrenceBanner(onChoose: () => _handleMarkDone(item)),
                    _Hero(item: item, status: status, now: now),
                    const SizedBox(height: AppSpacing.sp4),
                    if (!isDone) ...[
                      _LadderCard(item: item, now: now, isEntitled: isEntitled, onUnlock: _openPaywall),
                      const SizedBox(height: AppSpacing.sp4),
                    ],
                    if (item.type == RenewalType.healthCheck) ...[
                      _HealthRecurrenceCard(months: item.healthRecurrenceMonths ?? 12),
                      const SizedBox(height: AppSpacing.sp4),
                    ],
                    _NotesCard(notes: item.notes),
                  ],
                ),
                Positioned(
                  left: AppSpacing.sp2,
                  right: AppSpacing.sp2,
                  bottom: AppSpacing.sp2,
                  child: AnimatedBuilder(
                    animation: _undoController,
                    builder: (context, _) => UndoToast(controller: _undoController),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: _BottomBar(isDone: isDone, onEdit: () => _openEdit(item), onMarkDone: () => _handleMarkDone(item)),
          ),
        );
      },
    );
  }
}

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar({required this.item, required this.onDelete, required this.onUndoLastCompletion});

  final Renewal item;
  final VoidCallback onDelete;
  final VoidCallback? onUndoLastCompletion;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      title: Text(
        item.type.displayName,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
      ),
      actions: [
        // Overflow (⋮) menu — REQ-5.4's Delete entry, plus (new)
        // `Undo last completion` when available, per the product-manager
        // routing note in scope doc §3d. No separate confirmation dialog
        // on Delete — the undo toast is the safety net (scope doc §3c).
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _MenuAction.undoLastCompletion:
                onUndoLastCompletion?.call();
              case _MenuAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => [
            if (onUndoLastCompletion != null)
              const PopupMenuItem(
                value: _MenuAction.undoLastCompletion,
                child: Row(
                  children: [
                    Icon(Icons.undo, size: 18),
                    SizedBox(width: 10),
                    Text('Undo last completion'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: _MenuAction.delete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: scheme.error)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

enum _MenuAction { delete, undoLastCompletion }

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.status, required this.now});

  final Renewal item;
  final RenewalStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = status == RenewalStatus.done;
    final dueLine = isDone
        ? RelativeDateFormatter.doneLine(item.lastCompletedAt ?? item.updatedAt, null)
        : _dueLineWithSuffix();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeBadge(type: item.type, size: 52),
        const SizedBox(width: AppSpacing.sp3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(dueLine, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(status: status, size: 16),
                  const SizedBox(width: 6),
                  StatusChipView(label: status.sectionLabel, status: status),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dueLineWithSuffix() {
    final base = RelativeDateFormatter.dueLine(item.dueDate, now);
    if (item.type == RenewalType.healthCheck && item.healthRecurrenceMonths != null) {
      return '$base · every ${item.healthRecurrenceMonths} months';
    }
    if (item.type == RenewalType.custom && item.customTier != null) {
      return '$base · ${item.customTier!.displayName} lead time';
    }
    return base;
  }
}

class _LadderCard extends StatelessWidget {
  const _LadderCard({required this.item, required this.now, required this.isEntitled, required this.onUnlock});

  final Renewal item;
  final DateTime now;

  /// REQ-3.2/REQ-5.2 — the seam named in the developer task brief: "gate
  /// the rendering, not the data the helper produces." [LadderTrack.build]
  /// below is called identically regardless of tier; only this widget
  /// decides what renders locked.
  final bool isEntitled;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = LadderTrack.build(
      type: item.type,
      dueDate: item.dueDate,
      now: now,
      customTier: item.customTier,
    );
    final freeOffset =
        isEntitled ? null : LadderTables.freeReminderOffset(item.type, customTier: item.customTier);
    final lockedCount = freeOffset == null
        ? 0
        : entries.where((e) => e.kind == LadderTrackEntryKind.stage && e.offset != freeOffset).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEntitled ? 'Your reminder ladder' : 'Your reminder (free plan)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            isEntitled ? _ladderDescription(item.type) : _freeDescription,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
          ),
          LadderTrackView(entries: entries, freeOffset: freeOffset),
          const SizedBox(height: 6),
          if (isEntitled)
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activeNote(item.type),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
                ),
              ],
            )
          else if (lockedCount > 0)
            _UnlockBanner(count: lockedCount, reason: _unlockReason(item.type), onUnlock: onUnlock),
        ],
      ),
    );
  }

  // REQ-3.2: "Free plan gives every item one well-timed reminder — no
  // escalation, no overdue follow-up." matching `03-item-detail.html`
  // panel p3's free-tier header text verbatim.
  static const String _freeDescription =
      "Free plan gives every item one well-timed reminder — no escalation, no overdue follow-up. Here's where "
      'it sits against the full ladder:';

  // Developer-authored copy, following design doc §2's own per-type
  // reasoning column (only Passport and Health check are actually mocked
  // — `03-item-detail.html` panels p3/p5) — same "pattern given, not
  // every combination BA-drafted" situation REQ-15 already names for the
  // free-tier unlock banner and `NotificationCopy`'s own class doc
  // already flags for notification bodies. Worth a business-analyst pass,
  // not a silent substitute for one.
  static String _ladderDescription(RenewalType type) {
    switch (type) {
      case RenewalType.passport:
        return "Full 4-stage ladder — starts early enough that processing time isn't a surprise.";
      case RenewalType.insurance:
        return 'Full 3-stage ladder — tight to the deadline, since renewing is a same-day action.';
      case RenewalType.licence:
        return 'Full 3-stage ladder — starts earlier, since renewal usually needs accumulated hours and board processing time.';
      case RenewalType.vehicle:
        return 'Full 3-stage ladder — a days-to-weeks action, not a same-day one.';
      case RenewalType.warranty:
        return "Full 2-stage ladder — lighter by design, since there's nothing to fix by nagging once the window closes.";
      case RenewalType.healthCheck:
        return "Full 3-stage ladder — same days-to-weeks profile as Vehicle/Warranty, since booking an appointment isn't a same-day action.";
      case RenewalType.custom:
        return 'Full 3-stage ladder, based on the lead time you chose.';
    }
  }

  static String _activeNote(RenewalType type) {
    switch (type) {
      case RenewalType.passport:
        return 'Full ladder active — plus overdue follow-through if this passes unmarked';
      case RenewalType.healthCheck:
        return 'Full ladder active — if this passes unmarked, one lighter check-in follows 30 days later, then stops';
      case RenewalType.warranty:
        return 'Full ladder active — a single check-in on the due date, then nothing further to chase';
      default:
        return 'Full ladder active — plus overdue follow-through if this passes unmarked';
    }
  }

  /// REQ-3.2's `[BA DEFAULT]`: the unlock banner's explanatory line should
  /// be type-specific ("explains *why* the missing stages matter for that
  /// type"), reusing design doc §2's own per-type rationale column rather
  /// than one generic sentence for all seven types — only Passport is
  /// actually mocked (`03-item-detail.html` panel p3); the rest are this
  /// developer's own drafting from that same rationale column, same
  /// "worth a BA pass, not a silent substitute for one" flag as
  /// [_ladderDescription]/`NotificationCopy`.
  static String _unlockReason(RenewalType type) {
    switch (type) {
      case RenewalType.passport:
        return 'The 6-month and 1-month stages are what make a passport ladder actually work — that\'s the '
            'processing-backlog window.';
      case RenewalType.insurance:
        return "The 21-day stage is the one that gives you time to shop around before renewing at whatever "
            "price you're offered.";
      case RenewalType.licence:
        return 'The 90- and 30-day stages cover the time renewal usually needs for accumulated hours and board '
            'processing.';
      case RenewalType.vehicle:
        return "The 30- and 14-day stages are what give you time to book, not just a last-minute scramble.";
      case RenewalType.warranty:
        return 'The 30-day stage is the one that gives you time to actually use the warranty before it closes.';
      case RenewalType.healthCheck:
        return 'The 30- and 14-day stages are what give you time to actually get an appointment booked.';
      case RenewalType.custom:
        return "The earlier stages are what give you real lead time, not just a last-minute nudge.";
    }
  }
}

/// REQ-3.2's inline `.unlock-banner` — sits on the ladder track itself,
/// not as a separate interstitial, matching `03-item-detail.html` panel
/// p3's placement and copy pattern exactly (`"[N] more warnings live
/// here, unclaimed"` + type-specific reason + unlock button).
class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.count, required this.reason, required this.onUnlock});

  final int count;
  final String reason;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sp3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp3, vertical: 10),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11.5, color: scheme.onPrimaryContainer, height: 1.4),
                children: [
                  TextSpan(
                    text: '$count more warning${count == 1 ? '' : 's'} live here, unclaimed\n',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  TextSpan(text: reason),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onUnlock,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Unlock — \$3.99'),
          ),
        ],
      ),
    );
  }
}

class _HealthRecurrenceCard extends StatelessWidget {
  const _HealthRecurrenceCard({required this.months});

  final int months;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Remind me every', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          // REQ-1.3's copy-governance rule applies here too: describes the
          // user's own setting, never a clinical recommendation.
          Text(
            '$months months — your own setting, editable any time from Edit. Not a recommendation.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          // REQ-5.3: the card always renders; only its content changes.
          Text(
            (notes == null || notes!.isEmpty) ? 'No notes added.' : notes!,
            style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.isDone, required this.onEdit, required this.onMarkDone});

  final bool isDone;
  final VoidCallback onEdit;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A solid fill, not the mockup's gradient fade: this renders in
    // Scaffold's own `bottomNavigationBar` slot (see the build method's
    // comment), which sits *below* `body` rather than floating over its
    // scrollable content — there's nothing behind this bar to fade over.
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, 12, AppSpacing.sp4, 14),
      color: scheme.surface,
      child: Row(
        children: [
          if (isDone)
            OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit'))
          else ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onMarkDone,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Mark as done'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
