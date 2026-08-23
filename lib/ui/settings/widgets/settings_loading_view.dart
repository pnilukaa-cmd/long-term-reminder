import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Loading state, matching `06-settings-privacy.html` panel p1 — this
/// screen's only genuinely async work is checking the current
/// notification-permission status (see `SettingsScreen`), so this is a
/// brief flash in practice, but REQ-15.1 still calls for a real skeleton
/// rather than a blank frame.
class SettingsLoadingView extends StatelessWidget {
  const SettingsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp4, AppSpacing.sp4, AppSpacing.sp7),
      children: const [
        _SkeletonBlock(height: 96),
        SizedBox(height: AppSpacing.sp4),
        _SkeletonBlock(height: 140),
      ],
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(0 + _controller.value * 2, 0),
              colors: [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainer,
                scheme.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }
}
