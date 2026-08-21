import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import 'undo_controller.dart';

/// The dark snackbar-style undo toast, per design doc §4a — reused as a
/// single widget by both the list screen (delete/mark-done via
/// quick-action) and (in a future slice) item detail. Deliberately a
/// bespoke widget rather than `ScaffoldMessenger.showSnackBar` — the
/// 6-second window, the single-pending-action model, and the "commit
/// early on overlap" rule (REQ-10.2) are owned entirely by
/// [UndoController], and a hand-rolled widget keeps that the single
/// source of truth instead of fighting Material's own SnackBar queue.
class UndoToast extends StatelessWidget {
  const UndoToast({super.key, required this.controller});

  final UndoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pending = controller.pending;
        if (pending == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp4),
          child: Material(
            color: const Color(0xFF2B2B33),
            borderRadius: BorderRadius.circular(AppShapes.md),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pending.toastMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.undo,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: const Text(
                      'UNDO',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: .3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
