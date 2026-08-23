import 'package:flutter/material.dart';

import '../../data/repository/renewal_repository.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/format/relative_date.dart';
import '../../domain/ladder/ladder_track.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_status.dart';
import '../../domain/models/renewal_type.dart';
import '../../domain/status/status_calculator.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reconciliation_service.dart';
import '../../theme/app_dimens.dart';
import '../add_edit/add_edit_screen.dart';
import '../common/mark_done_sheet.dart';
import '../common/status_visuals.dart';
import '../common/type_badge.dart';
import '../common/undo_controller.dart';
import '../common/undo_toast.dart';
import 'widgets/deferred_recurrence_banner.dart';
import 'widgets/detail_loading_view.dart';
import 'widgets/detail_not_found_view.dart';
import 'widgets/ladder_track_view.dart';

/// Item detail — REQ-5, plus `Undo last completion` (scope doc §3d) and the
/// deferred recurrence banner that closes REQ-9.5's notification gap.
/// Matches `docs/design/mockups/03-item-detail.html`. Reachable by tapping a
/// card on the home list.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.repository,
    required this.settingsRepository,
    required this.notificationService,
    required this.reconciliationService,
  });

  final int itemId;
  final RenewalRepository repository;
  final SettingsRepository settingsRepository;

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
          notificationService: widget.notificationService,
          reconciliationService: widget.reconciliationService,
          existingItem: item,
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
                      _LadderCard(item: item, now: now),
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
  const _LadderCard({required this.item, required this.now});

  final Renewal item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = LadderTrack.build(
      type: item.type,
      dueDate: item.dueDate,
      now: now,
      customTier: item.customTier,
    );

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
          const Text('Your reminder ladder', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            _ladderDescription(item.type),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
          ),
          LadderTrackView(entries: entries),
          const SizedBox(height: 6),
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
          ),
        ],
      ),
    );
  }

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
