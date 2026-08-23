import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Load-failure state, matching `06-settings-privacy.html` panel p2 —
/// REQ-15.1 explicitly wants this to reassure the user their renewal data
/// isn't at risk, since this screen never holds any of it (everything shown
/// here is either a live OS-permission check or static copy).
class SettingsErrorView extends StatelessWidget {
  const SettingsErrorView({super.key, required this.onRetry});

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
              "Couldn't load settings",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Nothing lost — this screen doesn't hold your renewal data.",
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
