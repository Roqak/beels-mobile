import 'package:flutter/material.dart';

import '../money.dart';

/// Naira amount that counts up to [value] (and between later values).
/// Static under reduced motion.
class AnimatedNaira extends StatelessWidget {
  const AnimatedNaira(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final num value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(formatNaira(value), maxLines: 1, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (_, v, __) => Text(
        formatNaira(value is int ? v.round() : v),
        maxLines: 1,
        style: style,
      ),
    );
  }
}
