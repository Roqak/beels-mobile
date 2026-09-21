import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared shimmer clock. Wrap a group of [SkeletonBox]es so they pulse in
/// sync with one controller. Honors reduced motion (static fill).
class SkeletonScope extends StatefulWidget {
  const SkeletonScope({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonClock(
      animation: _c,
      child: ExcludeSemantics(child: widget.child),
    );
  }
}

class _SkeletonClock extends InheritedWidget {
  const _SkeletonClock({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonClock old) => animation != old.animation;
}

/// Rounded placeholder block with a soft sweep highlight.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final clock =
        context.dependOnInheritedWidgetOfExactType<_SkeletonClock>()?.animation;
    Widget box(double t) => Container(
          width: circle ? height : width,
          height: height,
          decoration: BoxDecoration(
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: [
                BeelsColors.fieldFill,
                BeelsColors.surfaceAlt,
                BeelsColors.fieldFill,
              ],
            ),
          ),
        );
    if (clock == null) return box(0.5);
    return AnimatedBuilder(
      animation: clock,
      builder: (_, __) => box(clock.value),
    );
  }
}

/// Skeleton for a list row (leading circle, two text lines, trailing amount).
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(height: 40, circle: true),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}
