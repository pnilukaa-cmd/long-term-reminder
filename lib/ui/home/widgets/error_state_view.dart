import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Local-read-failure state, matching `01-home-list.html` panel p3
/// (REQ-4.1). Never a blank white screen on a read error.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.onRetry});

  final VoidCallback onRetry;

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
              "Couldn't load your renewals",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your data is stored only on this device — this usually clears up on retry. '
              'If it keeps happening, restarting the app may help.',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sp5),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
