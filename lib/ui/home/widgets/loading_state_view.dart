import 'package:flutter/material.dart';

import '../../../theme/app_dimens.dart';

/// Skeleton shimmer cards, matching `01-home-list.html` panel p1
/// (loading / cold-load / any local-read-in-progress state).
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp2, AppSpacing.sp4, 100),
      children: const [
        _SkeletonBar(height: 74),
        SizedBox(height: AppSpacing.sp3),
        _SkeletonBar(height: 74),
        SizedBox(height: AppSpacing.sp3),
        _SkeletonBar(height: 74),
        SizedBox(height: AppSpacing.sp3),
        _SkeletonBar(height: 74, widthFactor: .7),
      ],
    );
  }
}

class _SkeletonBar extends StatefulWidget {
  const _SkeletonBar({required this.height, this.widthFactor = 1});

  final double height;
  final double widthFactor;

  @override
  State<_SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<_SkeletonBar> with SingleTickerProviderStateMixin {
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
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widget.widthFactor,
      child: AnimatedBuilder(
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
      ),
    );
  }
}
