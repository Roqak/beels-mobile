import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/widgets/primary_button.dart';
import 'package:beels_mobile/core/widgets/status_chip.dart';

void main() {
  group('statusKind', () {
    test('maps success-ish statuses to ok', () {
      expect(statusKind('Success'), StatusKind.ok);
      expect(statusKind('completed'), StatusKind.ok);
      expect(statusKind(' Active '), StatusKind.ok);
    });

    test('maps in-flight statuses to warn', () {
      expect(statusKind('pending'), StatusKind.warn);
      expect(statusKind('PROCESSING'), StatusKind.warn);
    });

    test('maps failure statuses to err', () {
      expect(statusKind('failed'), StatusKind.err);
      expect(statusKind('cancelled'), StatusKind.err);
      expect(statusKind('Rejected'), StatusKind.err);
      expect(statusKind('inactive'), StatusKind.err);
    });

    test('falls back to muted for unknown statuses', () {
      expect(statusKind('archived'), StatusKind.muted);
      expect(statusKind(''), StatusKind.muted);
    });
  });

  testWidgets('StatusChip renders its label with a dot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
              child: StatusChip(label: 'Pending', kind: StatusKind.warn)),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    expect(find.byType(StatusChip), findsOneWidget);
  });

  testWidgets('PrimaryButton hides its label and blocks taps while loading',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Save',
            onPressed: () => taps++,
            loading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('PrimaryButton shows label and icon when idle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Create',
            onPressed: () => taps++,
            icon: Icons.add,
          ),
        ),
      ),
    );

    expect(find.text('Create'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(taps, 1);
  });
}
