import 'package:flutter/material.dart';

import '../theme.dart';

/// Section title row with an optional trailing action (e.g. a TextButton).
/// No outer padding — the parent screen owns spacing.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: BeelsColors.ink0,
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
