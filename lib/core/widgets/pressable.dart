import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap target with a subtle press-scale and optional light haptic. Use for
/// custom cards and tiles instead of bare GestureDetector so every tappable
/// surface feels the same.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = false,
    this.semanticLabel,
    this.selected,
    this.borderRadius = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;
  final String? semanticLabel;

  /// Whether the control is in its active/selected state; exposed to
  /// semantics so colour-only selection is still conveyed to screen readers.
  final bool? selected;
  final double borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down && !reduce ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutQuart,
          child: widget.child,
        ),
      ),
    );
  }
}
