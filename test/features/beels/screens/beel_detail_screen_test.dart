import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/beels/controllers/beels_controllers.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/screens/beel_detail_screen.dart';
import 'package:beels_mobile/features/payments/data/payments_repository.dart';

import 'package:beels_mobile/features/payments/models/bank.dart';
import 'package:beels_mobile/features/payments/models/payment_mandate.dart';

class _FakeBeelDetailController extends BeelDetailController {
  @override
  FutureOr<Contribution> build(int arg) => _beel();

  @override
  Future<void> refresh() async {}
}

Contribution _beel() => Contribution.fromJson({
      'id': 27,
      'name': 'Family Savings',
      'unit_amount': '5000',
      'total_amount': '60000',
      'amount_paid': '25000',
      'status': 'active',
      'recurrence_type': 'weekly',
      'day_of_week': 'monday',
      'next_occurrence': '2026-09-21T00:00:00.000Z',
      'occurrences': 12,
      'contribution_mode': 'closed',
      'contributors': [
        {
          'id': 101,
          'first_name': 'Ada',
          'last_name': 'Okafor',
          'email': 'ada@beels.test',
          'unit_amount': '5000',
          'amount_paid': '15000',
          'status': 'active',
          'payment_id': 'JYLCWKtfdHVzihITWPSq',
        },
        {
          'id': 102,
          'first_name': 'Bode',
          'last_name': 'Aliu',
          'email': 'bode@beels.test',
          'unit_amount': '5000',
          'amount_paid': '10000',
          'status': 'settled',
          'payment_id': 'settledPaymentId',
        },
        {
          'id': 103,
          'first_name': 'Chidi',
          'last_name': 'Eze',
          'email': 'chidi@beels.test',
          'unit_amount': '5000',
          'amount_paid': '0',
          'status': 'pending',
        },
      ],
      'beneficiaries': [],
    });

class _FakePaymentsRepository implements PaymentsRepository {
  final List<String> initializedIds = <String>[];
  String initializeResult = 'https://checkout.flutterwave.com/pay/abc';
  Object? initializeError;

  @override
  Future<String> initializePayment(String paymentId) async {
    final error = initializeError;
    if (error != null) throw error;
    initializedIds.add(paymentId);
    return initializeResult;
  }

  @override
  Future<List<Bank>> getBanks() async => <Bank>[];

  @override
  Future<List<PaymentMandate>> listMandates() async => <PaymentMandate>[];

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
  Future<void> revokeMandate(int id) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakePaymentsRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        beelDetailControllerProvider.overrideWith(
          () => _FakeBeelDetailController(),
        ),
        paymentsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: BeelDetailScreen(id: 27)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
  });

  testWidgets('Pay now shows only for payable contributors and shares the '
      'checkout URL', (tester) async {
    final repository = _FakePaymentsRepository();
    var sharedTexts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        sharedTexts.add(call.arguments['text'] as String? ?? '');
        return null;
      },
    );

    await _pump(tester, repository: repository);

    // Ada (active + payment id) is payable; Bode (settled) and Chidi
    // (no payment id) are not.
    expect(find.text('Pay now'), findsOneWidget);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(repository.initializedIds, ['JYLCWKtfdHVzihITWPSq']);
    expect(sharedTexts, ['https://checkout.flutterwave.com/pay/abc']);
  });

  testWidgets('failed initialization surfaces the API message',
      (tester) async {
    final repository = _FakePaymentsRepository();
    repository.initializeError =
        const ApiException('No pending deposit', statusCode: 400);

    await _pump(tester, repository: repository);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(find.text('No pending deposit'), findsOneWidget);
    expect(repository.initializedIds, isEmpty);
  });

  testWidgets('empty checkout URL shows a friendly fallback message',
      (tester) async {
    final repository = _FakePaymentsRepository();
    repository.initializeResult = '';

    await _pump(tester, repository: repository);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(find.text('Payment link unavailable. Try again.'),
        findsOneWidget);
  });
}