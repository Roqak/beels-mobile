import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/dashboard/widgets/flow_chart.dart';

Map<String, dynamic> _row(String type, num amount, DateTime at) => {
      'type': type,
      'amount': amount,
      'status': 'successful',
      'created_at': at.toIso8601String(),
    };

Widget _app(List<Map<String, dynamic>> rows) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FlowChartCard(rows: rows),
        ),
      ),
    );

void main() {
  final now = DateTime.now();
  final rows = [
    _row('deposit', 5000, now.subtract(const Duration(days: 20))),
    _row('withdrawal', 1500, now.subtract(const Duration(days: 10))),
    _row('deposit', 2000, now.subtract(const Duration(days: 2))),
  ];

  testWidgets('shows the headline net flow and the default range',
      (tester) async {
    await tester.pumpWidget(_app(rows));
    await tester.pumpAndSettle();

    expect(find.text('Net flow'), findsOneWidget);
    // 5000 - 1500 + 2000
    expect(find.text('+₦5,500'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
  });

  testWidgets('changing the range recomputes the headline', (tester) async {
    await tester.pumpWidget(_app(rows));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1W'));
    await tester.pumpAndSettle();

    // Only the 2-day-old deposit falls inside the last 7 days.
    expect(find.text('+₦2,000'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
  });

  testWidgets('scrubbing shows the value and date at the finger',
      (tester) async {
    await tester.pumpWidget(_app(rows));
    await tester.pumpAndSettle();

    final chart = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter != null,
    );
    final box = tester.getRect(chart);
    final gesture =
        await tester.startGesture(box.centerLeft + const Offset(4, 0));
    // Tap-down is reported after the press timeout when a drag can also win.
    await tester.pump(const Duration(milliseconds: 150));

    // At the far left the running total is still the baseline.
    expect(find.text('+₦0'), findsOneWidget);
    expect(find.text('Last 30 days'), findsNothing);

    await gesture.moveTo(box.centerRight - const Offset(4, 0));
    await tester.pump();
    expect(find.text('+₦5,500'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Last 30 days'), findsOneWidget);
  });

  testWidgets('a quiet period explains itself instead of drawing nothing',
      (tester) async {
    await tester.pumpWidget(_app([
      _row('deposit', 1000, now.subtract(const Duration(days: 200))),
    ]));
    await tester.pumpAndSettle();

    expect(
        find.text('No settled activity in this period yet.'), findsOneWidget);
    expect(find.text('+₦0'), findsOneWidget);
  });

  testWidgets('a negative net flow reads as a loss', (tester) async {
    await tester.pumpWidget(_app([
      _row('withdrawal', 4000, now.subtract(const Duration(days: 3))),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('−₦4,000'), findsOneWidget);
  });
}
