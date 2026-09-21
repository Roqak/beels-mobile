import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/flow_series.dart';

/// Net-flow card for Home: headline value, range picker and a line chart you
/// can scrub with a finger (a light haptic ticks as it crosses each point).
class FlowChartCard extends StatefulWidget {
  const FlowChartCard({super.key, required this.rows, this.now});

  final List<Map<String, dynamic>> rows;

  /// Overrides "today" (tests and goldens); defaults to the real clock.
  final DateTime? now;

  @override
  State<FlowChartCard> createState() => _FlowChartCardState();
}

class _FlowChartCardState extends State<FlowChartCard> {
  FlowRange _range = FlowRange.month;
  int? _scrub;

  void _scrubTo(double dx, double width, List<FlowPoint> points) {
    if (points.length < 2 || width <= 0) return;
    final t = (dx / width).clamp(0.0, 1.0);
    final first = points.first.day.millisecondsSinceEpoch;
    final span = points.last.day.millisecondsSinceEpoch - first;
    final target = first + t * span;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i].day.millisecondsSinceEpoch - target).abs();
      if (d < bestDist) {
        bestDist = d.toDouble();
        best = i;
      }
    }
    if (best != _scrub) {
      HapticFeedback.selectionClick();
      setState(() => _scrub = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = buildFlowSeries(widget.rows, _range, now: widget.now);
    final hasChart = points.length >= 2;
    final index = (_scrub != null && _scrub! < points.length) ? _scrub : null;
    final shown = hasChart ? points[index ?? points.length - 1] : null;
    final value = shown?.value ?? 0;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Net flow',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BeelsColors.ink2,
                ),
              ),
              const Spacer(),
              _RangePicker(
                value: _range,
                onChanged: (r) => setState(() {
                  _range = r;
                  _scrub = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatNairaSigned(value.abs(), incoming: value >= 0),
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: value >= 0 ? BeelsColors.ink0 : BeelsColors.err,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            index != null
                ? DateFormat('EEE, d MMM yyyy').format(points[index].day)
                : _range.caption,
            style: TextStyle(fontSize: 12, color: BeelsColors.ink2),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: hasChart
                ? LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (d) =>
                          _scrubTo(d.localPosition.dx, box.maxWidth, points),
                      onHorizontalDragUpdate: (d) =>
                          _scrubTo(d.localPosition.dx, box.maxWidth, points),
                      onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                      onHorizontalDragCancel: () =>
                          setState(() => _scrub = null),
                      onTapDown: (d) =>
                          _scrubTo(d.localPosition.dx, box.maxWidth, points),
                      onTapUp: (_) => setState(() => _scrub = null),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_range),
                        tween: Tween(begin: 0, end: 1),
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 700),
                        curve: Curves.easeOutQuart,
                        builder: (_, t, __) => CustomPaint(
                          size: Size(box.maxWidth, 132),
                          painter: _FlowPainter(
                            points: points,
                            progress: t,
                            scrub: index,
                            line: BeelsColors.accent,
                            grid: BeelsColors.border,
                            dotFill: BeelsColors.panel,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'No settled activity in this period yet.',
                      style: TextStyle(fontSize: 13, color: BeelsColors.ink2),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.value, required this.onChanged});

  final FlowRange value;
  final ValueChanged<FlowRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final range in FlowRange.values)
          Semantics(
            button: true,
            selected: range == value,
            label: range.caption,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (range == value) return;
                HapticFeedback.selectionClick();
                onChanged(range);
              },
              child: Container(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                alignment: Alignment.center,
                margin: const EdgeInsets.only(left: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: range == value
                      ? BeelsColors.accentSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        range == value ? BeelsColors.accent : BeelsColors.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.points,
    required this.progress,
    required this.scrub,
    required this.line,
    required this.grid,
    required this.dotFill,
  });

  final List<FlowPoint> points;
  final double progress;
  final int? scrub;
  final Color line;
  final Color grid;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const padTop = 8.0;
    const padBottom = 8.0;
    const padX = 8.0; // keeps the end marker fully inside the card
    final plotW = size.width - padX * 2;
    final plotH = size.height - padTop - padBottom;

    final first = points.first.day.millisecondsSinceEpoch.toDouble();
    final span =
        (points.last.day.millisecondsSinceEpoch - first).clamp(1, 1 << 62);
    var lo = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    var hi = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    if (lo > 0) lo = 0; // always show the zero line for context
    if (hi < 0) hi = 0;
    if (hi - lo < 1) hi = lo + 1;

    Offset at(FlowPoint p) => Offset(
          padX + (p.day.millisecondsSinceEpoch - first) / span * plotW,
          padTop + (1 - (p.value - lo) / (hi - lo)) * plotH,
        );

    // Zero baseline.
    final zeroY = padTop + (1 - (0 - lo) / (hi - lo)) * plotH;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const dash = 4.0;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, zeroY),
          Offset((x + dash).clamp(0, size.width), zeroY), gridPaint);
    }

    // Line path (drawn in as `progress` grows).
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final p = at(points[i]);
      path.lineTo(p.dx, p.dy);
    }
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final drawn = Path();
    var remaining = total * progress;
    for (final PathMetric m in metrics) {
      if (remaining <= 0) break;
      drawn.addPath(
          m.extractPath(0, remaining.clamp(0, m.length)), Offset.zero);
      remaining -= m.length;
    }

    // Soft flat area under the line (no gradient).
    final area = Path.from(drawn);
    final end = drawn.computeMetrics().fold<Offset?>(null, (_, m) {
      return m.getTangentForOffset(m.length)?.position;
    });
    if (end != null) {
      area
        ..lineTo(end.dx, zeroY)
        ..lineTo(at(points.first).dx, zeroY)
        ..close();
      canvas.drawPath(area, Paint()..color = line.withOpacity(0.10));
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Marker: scrubbed point, else the latest.
    final marker = at(points[scrub ?? points.length - 1]);
    if (scrub != null) {
      canvas.drawLine(
        Offset(marker.dx, 0),
        Offset(marker.dx, size.height),
        Paint()
          ..color = line.withOpacity(0.35)
          ..strokeWidth = 1.5,
      );
    }
    if (progress > 0.98 || scrub != null) {
      canvas.drawCircle(marker, 6, Paint()..color = dotFill);
      canvas.drawCircle(
        marker,
        6,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.progress != progress ||
      old.scrub != scrub ||
      old.points != points ||
      old.line != line;
}
