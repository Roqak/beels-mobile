import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/dashboard/data/flow_series.dart';

Map<String, dynamic> _row(
  String type,
  num amount,
  DateTime at, {
  String status = 'successful',
}) =>
    {
      'type': type,
      'amount': amount,
      'status': status,
      'created_at': at.toIso8601String(),
    };

void main() {
  final today = DateTime(2026, 9, 21);

  test('no rows means no series', () {
    expect(buildFlowSeries(const [], FlowRange.month, now: today), isEmpty);
  });

  test('only settled transactions count', () {
    final rows = [
      _row('deposit', 1000, DateTime(2026, 9, 20)),
      _row('deposit', 5000, DateTime(2026, 9, 20), status: 'pending'),
      _row('deposit', 7000, DateTime(2026, 9, 20), status: 'failed'),
    ];
    final s = buildFlowSeries(rows, FlowRange.month, now: today);
    expect(s.last.value, 1000);
  });

  test('deposits add, withdrawals subtract, same day is aggregated', () {
    final rows = [
      _row('deposit', 5000, DateTime(2026, 9, 18, 9)),
      _row('withdrawal', 2000, DateTime(2026, 9, 18, 17)),
      _row('deposit', 1000, DateTime(2026, 9, 20)),
    ];
    final s = buildFlowSeries(rows, FlowRange.month, now: today);

    // baseline, 18th, 20th, then today (flat).
    expect(s.map((p) => p.value), [0, 3000, 4000, 4000]);
    expect(s[1].day, DateTime(2026, 9, 18));
  });

  test('starts at zero at the range start and ends today', () {
    final rows = [_row('deposit', 1000, DateTime(2026, 9, 15))];
    final s = buildFlowSeries(rows, FlowRange.week, now: today);

    expect(s.first.value, 0);
    expect(s.first.day, DateTime(2026, 9, 15)); // today minus 6 days
    expect(s.last.day, today);
    expect(s.last.value, 1000);
  });

  test('range excludes older activity', () {
    final rows = [
      _row('deposit', 9000, DateTime(2026, 6, 1)),
      _row('deposit', 1000, DateTime(2026, 9, 19)),
    ];
    expect(buildFlowSeries(rows, FlowRange.week, now: today).last.value, 1000);
    expect(buildFlowSeries(rows, FlowRange.all, now: today).last.value, 10000);
  });

  test('a range with nothing settled inside it is empty', () {
    final rows = [_row('deposit', 9000, DateTime(2026, 1, 1))];
    expect(buildFlowSeries(rows, FlowRange.month, now: today), isEmpty);
  });

  test('all-range baseline sits the day before the first activity', () {
    final rows = [_row('deposit', 500, DateTime(2026, 9, 10))];
    final s = buildFlowSeries(rows, FlowRange.all, now: today);
    expect(s.first.day, DateTime(2026, 9, 9));
    expect(s.first.value, 0);
  });

  test('future-dated rows are ignored', () {
    final rows = [_row('deposit', 1000, DateTime(2026, 9, 30))];
    expect(buildFlowSeries(rows, FlowRange.all, now: today), isEmpty);
  });
}
