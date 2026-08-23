import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// "Item not found" state, matching `03-item-detail.html` panel p2
/// (REQ-5.1) — reachable when the item was deleted in another flow (e.g. the
/// undo window lapsed on a different screen, or `Delete` was used elsewhere)
/// while a stale reference to it is still open here. Must not crash; offers
/// a way back.
class DetailNotFoundView extends StatelessWidget {
  const DetailNotFoundView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5, vertical: AppSpacing.sp7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: scheme.errorContainer, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 26),
            ),
            const SizedBox(height: AppSpacing.sp4),
            const Text(
              "This item isn't here anymore",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'It may have been deleted. Nothing to worry about on our end — your other renewals are untouched.',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sp5),
            OutlinedButton(onPressed: onBack, child: const Text('Back to your renewals')),
          ],
        ),
      ),
    );
  }
}
