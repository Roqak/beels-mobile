import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/payments/data/payments_repository.dart';
import 'package:beels_mobile/features/payments/models/bank.dart';
import 'package:beels_mobile/features/payments/models/payment_mandate.dart';
import 'package:beels_mobile/features/payments/screens/mandate_list_screen.dart';

class _FakePaymentsRepository implements PaymentsRepository {
  _FakePaymentsRepository({this.rows = const []});

  List<PaymentMandate> rows;
  final List<int> revokedIds = <int>[];
  int listCalls = 0;

  @override
  Future<List<PaymentMandate>> listMandates() async {
    listCalls++;
    return rows;
  }

  @override
  Future<void> revokeMandate(int id) async {
    revokedIds.add(id);
  }

  @override
  Future<List<Bank>> getBanks() async => <Bank>[];

  @override
  Future<String> nameEnquiry({
    required String accountNumber,
    required String bankCode,
  }) async =>
      '';

  @override
  Future<void> setupMandate({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String accountNumber,
    required String bankName,
    required String bankCode,
    required String bvn,
  }) async {}

  @override
  Future<String> initializePayment(String paymentId) async => '';
}

PaymentMandate _mandate({
  int id = 7,
  String status = 'ACTIVE',
  String bankName = 'GTBank',
}) =>
    PaymentMandate.fromJson({
      'id': id,
      'account_number': '0123456789',
      'bank_code': '058',
      'bank_name': bankName,
      'status': status,
      'created_at': '2026-01-02T03:04:05.000Z',
    });

Future<void> _pump(
  WidgetTester tester, {
  required _FakePaymentsRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        paymentsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: MandateListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders mandates with bank, masked account and status',
      (tester) async {
    await _pump(
      tester,
      repository: _FakePaymentsRepository(rows: [_mandate()]),
    );

    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('•••• 6789'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('revoke confirms, calls the API and refreshes the list',
      (tester) async {
    final repository = _FakePaymentsRepository(rows: [_mandate()]);
    await _pump(tester, repository: repository);

    await tester.tap(find.byTooltip('Revoke mandate'));
    await tester.pumpAndSettle();

    expect(find.text('Revoke mandate?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
    await tester.pumpAndSettle();

    expect(repository.revokedIds, [7]);
    // The controller refreshes after revocation.
    expect(repository.listCalls, greaterThanOrEqualTo(2));
    expect(find.text('Mandate revoked.'), findsOneWidget);
  });

  testWidgets('cancelling the dialog leaves the mandate untouched',
      (tester) async {
    final repository = _FakePaymentsRepository(rows: [_mandate()]);
    await _pump(tester, repository: repository);

    await tester.tap(find.byTooltip('Revoke mandate'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.revokedIds, isEmpty);
  });

  testWidgets('empty state offers the setup action', (tester) async {
    await _pump(
      tester,
      repository: _FakePaymentsRepository(rows: []),
    );

    expect(find.text('No direct debit yet'), findsOneWidget);
    expect(find.text('Set up mandate'), findsOneWidget);
  });
}