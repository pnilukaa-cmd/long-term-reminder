import 'package:flutter/material.dart';

import '../../data/repository/renewal_repository.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_status.dart';
import '../../domain/models/renewal_type.dart';
import '../../domain/status/status_calculator.dart';
import '../../theme/app_dimens.dart';
import '../add_edit/add_edit_screen.dart';
import '../common/mark_done_sheet.dart';
import '../common/undo_controller.dart';
import '../common/undo_toast.dart';
import 'widgets/empty_state_view.dart';
import 'widgets/error_state_view.dart';
import 'widgets/loading_state_view.dart';
import 'widgets/renewal_card.dart';

/// The hub screen — REQ-4.1's four states, REQ-4.2's status grouping,
/// REQ-4.3's quick-done, and REQ-5.4/§0.2's long-press delete affordance.
/// Matches `docs/design/mockups/01-home-list.html`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.settingsRepository});

  final RenewalRepository repository;
  final SettingsRepository settingsRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final UndoController _undoController = UndoController(widget.repository);

  // Reused across rebuilds rather than calling `repository.watchAll()`
  // fresh inside `build()` — the latter would hand `StreamBuilder` a new
  // `Stream` instance on every rebuild (e.g. every long-press-reveal
  // toggle), resetting its connection state back to `waiting` and
  // flashing the loading skeleton over an already-loaded list. Only
  // reassigned by [_retryLoad], for the error state's "Try again".
  late Stream<List<Renewal>> _itemsStream = widget.repository.watchAll();

  int? _revealedItemId;

  @override
  void dispose() {
    _undoController.dispose();
    super.dispose();
  }

  void _retryLoad() => setState(() => _itemsStream = widget.repository.watchAll());

  void _clearReveal() {
    if (_revealedItemId != null) setState(() => _revealedItemId = null);
  }

  Future<void> _handleQuickDone(Renewal item) async {
    _clearReveal();
    final outcome = await showMarkDoneFlow(context, item);
    if (!outcome.confirmed) return;
    await _undoController.scheduleMarkDone(item, nextDueDate: outcome.nextDueDate);
  }

  void _handleDelete(Renewal item) {
    setState(() => _revealedItemId = null);
    _undoController.scheduleDelete(item);
  }

  Future<void> _openAddEdit({RenewalType? initialType}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          repository: widget.repository,
          settingsRepository: widget.settingsRepository,
          initialType: initialType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your renewals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings isn't built yet — coming in a later slice.")),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Renewal>>(
          stream: _itemsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const LoadingStateView();
            }
            if (snapshot.hasError) {
              return ErrorStateView(onRetry: _retryLoad);
            }

            final allItems = snapshot.data ?? const <Renewal>[];
            if (allItems.isEmpty) {
              return EmptyStateView(onTypeSelected: (type) => _openAddEdit(initialType: type));
            }

            final visibleItems = _undoController.applyOverlay(allItems);

            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _clearReveal,
                  child: _SuccessList(
                    items: visibleItems,
                    revealedItemId: _revealedItemId,
                    onLongPress: (id) => setState(() => _revealedItemId = id),
                    onTapWhileRevealed: _clearReveal,
                    onQuickDone: _handleQuickDone,
                    onDelete: _handleDelete,
                  ),
                ),
                Positioned(
                  left: AppSpacing.sp4,
                  right: AppSpacing.sp4,
                  bottom: AppSpacing.sp5,
                  child: AnimatedBuilder(
                    animation: _undoController,
                    builder: (context, _) => UndoToast(controller: _undoController),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _undoController,
        builder: (context, _) {
          final raised = _undoController.pending != null;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: raised ? 64 : 0),
            child: FloatingActionButton(
              onPressed: () => _openAddEdit(),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}

class _SuccessList extends StatelessWidget {
  const _SuccessList({
    required this.items,
    required this.revealedItemId,
    required this.onLongPress,
    required this.onTapWhileRevealed,
    required this.onQuickDone,
    required this.onDelete,
  });

  final List<Renewal> items;
  final int? revealedItemId;
  final ValueChanged<int> onLongPress;
  final VoidCallback onTapWhileRevealed;
  final ValueChanged<Renewal> onQuickDone;
  final ValueChanged<Renewal> onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final grouped = <RenewalStatus, List<Renewal>>{for (final s in RenewalStatus.sectionOrder) s: <Renewal>[]};

    for (final item in items) {
      final status = StatusCalculator.computeStatus(
        type: item.type,
        dueDate: item.dueDate,
        isDone: item.isDone,
        now: now,
        customTier: item.customTier,
      );
      grouped[status]!.add(item);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        if (entry.key == RenewalStatus.done) {
          final aDate = a.lastCompletedAt ?? a.updatedAt;
          final bDate = b.lastCompletedAt ?? b.updatedAt;
          return bDate.compareTo(aDate);
        }
        return a.dueDate.compareTo(b.dueDate);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp2, AppSpacing.sp4, 140),
      children: [
        for (final status in RenewalStatus.sectionOrder)
          if (grouped[status]!.isNotEmpty) ...[
            _SectionLabel(status.sectionLabel),
            for (final item in grouped[status]!)
              RenewalCard(
                key: ValueKey(item.id),
                item: item,
                status: status,
                now: now,
                isRevealed: revealedItemId == item.id,
                isDimmed: revealedItemId != null && revealedItemId != item.id,
                onQuickDone: () => onQuickDone(item),
                onLongPress: () => onLongPress(item.id),
                onTapWhileRevealed: onTapWhileRevealed,
                onDelete: () => onDelete(item),
              ),
          ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sp4, bottom: AppSpacing.sp2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
