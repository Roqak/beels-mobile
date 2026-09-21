import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Procedural adire (indigo resist-dye) motif field: alternating rings and
/// diamonds on an offset grid, brightest at the top-right and fading toward
/// the bottom-left so foreground numbers stay legible. No image assets.
class AdirePattern extends StatelessWidget {
  const AdirePattern({super.key, this.cell = 30, this.progress = 1});

  final double cell;

  /// 0..1 reveal (motifs grow in). Pass 1 for static.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AdirePainter(cell: cell, progress: progress),
        size: Size.infinite,
      ),
    );
  }
}

class _AdirePainter extends CustomPainter {
  _AdirePainter({required this.cell, required this.progress});

  final double cell;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final maxDist =
        math.sqrt(size.width * size.width + size.height * size.height);
    final origin = Offset(size.width, 0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final fill = Paint()..style = PaintingStyle.fill;
    var row = 0;
    for (var y = cell / 2; y < size.height + cell; y += cell * 0.86, row++) {
      final shift = row.isOdd ? cell / 2 : 0.0;
      var col = 0;
      for (var x = -cell + shift; x < size.width + cell; x += cell, col++) {
        final c = Offset(x, y);
        final d = (c - origin).distance / maxDist;
        final a = (0.8 * (1 - d * 1.75)).clamp(0.0, 0.8) * progress;
        if (a <= 0.02) continue;
        final color = BeelsColors.dyeLine.withOpacity(a);
        stroke.color = color;
        fill.color = color;
        final r = cell * 0.28 * (0.6 + 0.4 * progress);
        if ((row + col).isEven) {
          canvas.drawCircle(c, r, stroke);
          canvas.drawCircle(c, r * 0.32, fill);
        } else {
          final path = Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close();
          canvas.drawPath(path, stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AdirePainter old) =>
      old.progress != progress || old.cell != cell;
}
