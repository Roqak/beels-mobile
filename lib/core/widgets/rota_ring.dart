import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One participant slot on the rota: [fraction] of their share paid (0..1).
class RotaSlot {
  const RotaSlot(this.fraction);
  final double fraction;
}

/// Circular rota: each participant is an arc; filled = paid, partly filled =
/// part-paid, hollow = outstanding. [center] sits inside the ring.
class RotaRing extends StatelessWidget {
  const RotaRing({
    super.key,
    required this.slots,
    required this.center,
    this.size = 148,
    this.stroke = 12,
    this.trackColor = BeelsColors.border,
    this.paidColor = BeelsColors.accent,
  });

  final List<RotaSlot> slots;
  final Widget center;
  final double size;
  final double stroke;
  final Color trackColor;
  final Color paidColor;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuart,
        builder: (_, t, child) => CustomPaint(
          painter: _RotaPainter(
            slots: slots,
            stroke: stroke,
            t: t,
            trackColor: trackColor,
            paidColor: paidColor,
          ),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RotaPainter extends CustomPainter {
  _RotaPainter({
    required this.slots,
    required this.stroke,
    required this.t,
    required this.trackColor,
    required this.paidColor,
  });

  final List<RotaSlot> slots;
  final double stroke;
  final double t;
  final Color trackColor;
  final Color paidColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (slots.isEmpty) return;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final n = slots.length;
    final gap = n == 1 ? 0.0 : math.min(0.14, (2 * math.pi / n) * 0.22);
    final sweep = 2 * math.pi / n - gap;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final paid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = paidColor;
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * (sweep + gap) + gap / 2;
      canvas.drawArc(rect, start, sweep, false, track);
      final f = (slots[i].fraction.clamp(0.0, 1.0)) * t;
      if (f > 0) canvas.drawArc(rect, start, sweep * f, false, paid);
    }
  }

  @override
  bool shouldRepaint(_RotaPainter old) =>
      old.t != t ||
      old.slots != slots ||
      old.stroke != stroke ||
      old.trackColor != trackColor ||
      old.paidColor != paidColor;
}
