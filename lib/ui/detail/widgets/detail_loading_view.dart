import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Skeleton state, matching `03-item-detail.html` panel p1 (REQ-5.1).
class DetailLoadingView extends StatelessWidget {
  const DetailLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double height, {double widthFactor = 1}) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.lg)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp4, AppSpacing.sp4, AppSpacing.sp7),
      children: [
        bar(52, widthFactor: .8),
        const SizedBox(height: AppSpacing.sp4),
        bar(130),
        const SizedBox(height: AppSpacing.sp3),
        bar(90),
      ],
    );
  }
}
