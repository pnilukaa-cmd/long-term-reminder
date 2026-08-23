import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repository/renewal_repository.dart';
import '../../domain/models/renewal.dart';

/// The two actions REQ-10.1 covers: delete and mark-done (list or detail
/// entry point — this slice only has the list entry point, since item
/// detail is out of scope for slice 1).
enum PendingActionType { delete, markDone }

/// A covered action that's in its 6-second undo window (REQ-10).
class PendingUndoAction {
  const PendingUndoAction({
    required this.type,
    required this.item,
    this.nextDueDate,
  });

  final PendingActionType type;

  /// Snapshot of the item at the moment the action was triggered — used
  /// both for the toast's copy ("Deleted — [item label]") and for the
  /// list-overlay merge in [UndoController.applyOverlay].
  final Renewal item;

  /// Only set for a mark-done action on a recurring type where a next due
  /// date was chosen (smart default or manual). Null for delete, for
  /// non-recurring mark-done (Warranty, or "No" to Custom's repeat
  /// prompt), and while nothing has been chosen yet.
  final DateTime? nextDueDate;

  String get toastMessage {
    switch (type) {
      case PendingActionType.delete:
        return 'Deleted — ${item.label}';
      case PendingActionType.markDone:
        return 'Marked done — ${item.label}';
    }
  }
}

/// Implements the undo-toast contract in full, per REQ-10:
///
/// - A covered action does **not** write to the database immediately —
///   it's held as a [PendingUndoAction] for [undoWindow] (REQ-10.2's
///   "the underlying data is actually removed at this point [window
///   lapse], not before" / "remaining ladder stages are actually
///   cancelled at this point").
/// - [applyOverlay] lets the list screen render the *effect* of the
///   pending action (item hidden, or shown as Done) without it having
///   actually happened in the database yet — so Undo is a true, free
///   revert: cancel the timer, drop the pending action, nothing to undo
///   in the database because nothing was written there.
/// - Only one action is ever pending at a time (REQ-10.2's overlap
///   default): scheduling a new covered action while one is already
///   pending commits the old one immediately, then starts a fresh window
///   for the new one.
class UndoController extends ChangeNotifier {
  UndoController(this._repository);

  final RenewalRepository _repository;

  static const Duration undoWindow = Duration(seconds: 6);

  PendingUndoAction? _pending;
  Timer? _timer;

  PendingUndoAction? get pending => _pending;

  Future<void> scheduleDelete(Renewal item) async {
    await _commitPendingIfAny();
    _pending = PendingUndoAction(type: PendingActionType.delete, item: item);
    _restartTimer();
    notifyListeners();
  }

  Future<void> scheduleMarkDone(Renewal item, {DateTime? nextDueDate}) async {
    await _commitPendingIfAny();
    _pending = PendingUndoAction(type: PendingActionType.markDone, item: item, nextDueDate: nextDueDate);
    _restartTimer();
    notifyListeners();
  }

  /// Full revert — nothing was ever written to the database, so this is
  /// just dropping the pending action.
  void undo() {
    _timer?.cancel();
    _timer = null;
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  /// Merges the pending action's effect into a freshly-loaded list from
  /// the live database stream, per the class doc above.
  List<Renewal> applyOverlay(List<Renewal> items) {
    final action = _pending;
    if (action == null) return items;
    switch (action.type) {
      case PendingActionType.delete:
        return items.where((item) => item.id != action.item.id).toList(growable: false);
      case PendingActionType.markDone:
        return items.map((item) {
          if (item.id != action.item.id) return item;
          // Mirrors the fixed invariant in RenewalDao.markDone (scope doc
          // §3d): `isDone` is only true for a genuinely terminal outcome
          // (no next due date). A recurring item that just picked its next
          // cycle is an ordinary item with a future due date, not a
          // parked "Done" item — the overlay must show that immediately,
          // not just the eventual DB write, or the list would flash the
          // item into the collapsed Done section for the 6-second undo
          // window even though it's about to re-open as Upcoming/Due
          // soon/Overdue the moment the window commits.
          final isTerminal = action.nextDueDate == null;
          return item.copyWith(isDone: isTerminal, dueDate: action.nextDueDate);
        }).toList(growable: false);
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(undoWindow, _commitPending);
  }

  Future<void> _commitPendingIfAny() {
    if (_pending == null) return Future.value();
    _timer?.cancel();
    _timer = null;
    return _commitPending();
  }

  Future<void> _commitPending() async {
    final action = _pending;
    if (action == null) return;
    _pending = null;
    notifyListeners();
    switch (action.type) {
      case PendingActionType.delete:
        await _repository.deleteItem(action.item.id);
      case PendingActionType.markDone:
        await _repository.commitMarkDone(action.item.id, nextDueDate: action.nextDueDate);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
