import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:beels_mobile/features/transactions/controllers/transactions_controllers.dart';
import 'package:beels_mobile/features/transactions/models/transaction.dart';
import 'package:beels_mobile/features/transactions/screens/transactions_screen.dart';

class _FakeTransactionsListController extends TransactionsListController {
  @override
  Future<TransactionsListState> build() async => TransactionsListState(
        items: [
          Transaction.fromJson({
            'id': 1,
            'type': 'deposit',
            'amount': 5000,
            'status': 'successful',
            'created_at': '2026-09-10T08:45:00.000Z',
            'deposit': {
              'transaction_reference': 'DEP-0001',
              'contributor': {
                'unit_amount': 5000,
                'contribution': {'name': 'Family Savings', 'total_amount': 60000},
              },
            },
          }),
        ],
        page: 1,
        lastPage: 1,
        total: 1,
      );
}

class _EmptyTransactionsListController extends TransactionsListController {
  @override
  Future<TransactionsListState> build() async => const TransactionsListState(
        items: [],
        page: 1,
        lastPage: 1,
        total: 0,
      );
}

class _FailingTransactionsListController extends TransactionsListController {
  @override
  Future<TransactionsListState> build() async => throw Exception('down');
}

Widget _app(TransactionsListController controller) {
  return ProviderScope(
    overrides: [
      transactionsListControllerProvider.overrideWith(() => controller),
    ],
    child: const MaterialApp(home: TransactionsScreen()),
  );
}

void main() {
  final expectedDate = DateFormat('d MMM, yyyy · HH:mm')
      .format(DateTime.utc(2026, 9, 10, 8, 45).toLocal());

  testWidgets('renders a transaction row with badge, name, date and amount',
      (tester) async {
    await tester.pumpWidget(_app(_FakeTransactionsListController()));
    await tester.pumpAndSettle();

    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Family Savings'), findsOneWidget);
    expect(find.text('DEP-0001  ·  $expectedDate'), findsOneWidget);
    expect(find.text('+₦5,000'), findsOneWidget);
    expect(find.text('successful'), findsOneWidget);
  });

  testWidgets('expands a row into the detail card on tap', (tester) async {
    await tester.pumpWidget(_app(_FakeTransactionsListController()));
    await tester.pumpAndSettle();

    expect(find.text('Reference'), findsNothing);

    await tester.tap(find.text('Family Savings'));
    await tester.pumpAndSettle();

    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('DEP-0001'), findsOneWidget);
    expect(find.text('Beel'), findsOneWidget);
    expect(find.text('Unit Amount'), findsOneWidget);
    // Unit Amount and Amount rows show the same figure in this fixture.
    expect(find.text('₦5,000'), findsNWidgets(2));
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.text('₦60,000'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no history',
      (tester) async {
    await tester.pumpWidget(
        _app(_EmptyTransactionsListController()));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
  });

  testWidgets('shows the error view on failure', (tester) async {
    await tester.pumpWidget(_app(_FailingTransactionsListController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error-view')), findsOneWidget);
  });
}