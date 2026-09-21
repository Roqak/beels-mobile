import 'package:flutter/material.dart';

import '../money.dart';
import '../theme.dart';

/// Formatted naira amount. Default: signed (`+₦`/`−₦`) and colored by
/// direction. `strong: true` renders a neutral bold unsigned amount for
/// stat cards and totals.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.incoming = true,
    this.strong = false,
  });

  final num amount;
  final bool incoming;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: strong ? 16 : 14,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
      color: strong
          ? BeelsColors.ink0
          : (incoming ? BeelsColors.ok : BeelsColors.err),
    );
    return Text(
      strong
          ? formatNaira(amount)
          : formatNairaSigned(amount, incoming: incoming),
      style: style,
    );
  }
}
