import 'dashboard_repository.dart';

/// Ranges offered above the chart.
enum FlowRange {
  week('1W', 'Last 7 days', 7),
  month('1M', 'Last 30 days', 30),
  quarter('3M', 'Last 90 days', 90),
  all('All', 'All loaded activity', null);

  const FlowRange(this.label, this.caption, this.days);

  final String label;
  final String caption;
  final int? days;
}

/// One point on the chart: cumulative net flow (deposits minus withdrawals)
/// at the end of [day].
class FlowPoint {
  const FlowPoint(this.day, this.value);

  final DateTime day;
  final double value;
}

const _countedStatuses = {'successful', 'success', 'completed'};

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Turns raw transaction rows into a cumulative net-flow series for [range].
///
/// Only settled transactions count. The series starts from zero at the start
/// of the range, so it reads as "change over this period", and always ends
/// today so a quiet stretch shows as a flat line rather than stopping early.
/// Returns an empty list when nothing settled falls inside the range.
List<FlowPoint> buildFlowSeries(
  List<Map<String, dynamic>> rows,
  FlowRange range, {
  DateTime? now,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final cutoff = range.days == null
      ? null
      : today.subtract(Duration(days: range.days! - 1));

  final perDay = <DateTime, double>{};
  for (final row in rows) {
    if (!_countedStatuses.contains(row.txnStatus.toLowerCase())) continue;
    final at = row.txnDate;
    if (at == null) continue;
    final day = _dayOf(at.toLocal());
    if (day.isAfter(today)) continue;
    if (cutoff != null && day.isBefore(cutoff)) continue;
    final signed = row.txnAmount.toDouble() * (row.isIncoming ? 1 : -1);
    perDay[day] = (perDay[day] ?? 0) + signed;
  }
  if (perDay.isEmpty) return const [];

  final days = perDay.keys.toList()..sort();
  final start = cutoff ?? days.first.subtract(const Duration(days: 1));

  final points = <FlowPoint>[FlowPoint(start, 0)];
  var running = 0.0;
  for (final day in days) {
    running += perDay[day]!;
    points.add(FlowPoint(day, running));
  }
  if (points.last.day.isBefore(today)) {
    points.add(FlowPoint(today, running));
  }
  return points;
}
