import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/beels/controllers/beels_controllers.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/screens/beel_detail_screen.dart';
import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
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
          'account_number': '9016323384',
          'bank_code': '076',
          'quick_debit_identifier': 'nCFf1kFMUyCWgZ7iIAEz',
          'quick_debit_status': 'pending',
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
          'quick_debit_identifier': 'chidiDebitId',
          'quick_debit_status': 'active',
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

class _FakeBeelsRepository implements BeelsRepository {
  final List<({String identifier, String bankCode, String accountNumber})>
      activations = <({String identifier, String bankCode, String accountNumber})>[];
  Object? activationError;

  @override
  Future<QuickDebitActivation> initiateQuickDebit({
    required String identifier,
    required String bankCode,
    required String accountNumber,
  }) async {
    final error = activationError;
    if (error != null) throw error;
    activations.add((
      identifier: identifier,
      bankCode: bankCode,
      accountNumber: accountNumber,
    ));
    return QuickDebitActivation(
      accountName: 'PWA Live Test',
      accountNumber: '9016323384',
      bankName: 'Polaris Bank Limited',
      expiryDate: '2026-09-23 20:26:55',
    );
  }

  @override
  Future<Paginated<Contribution>> list({int page = 1, int perPage = 20}) async =>
      Paginated.parse(const {}, Contribution.fromJson);

  @override
  Future<Contribution> get(int id) async => Contribution.fromJson(const {});

  @override
  Future<Contribution> create({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) async =>
      Contribution.fromJson(const {});

  @override
  Future<Contribution> createOpen({
    required String name,
    required num amount,
    num? amountPerContributor,
    int? expectedContributors,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<BeneficiaryInput> beneficiaries,
  }) async =>
      Contribution.fromJson(const {});

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> retry(int id) async {}

  @override
  Future<void> disburse({
    required int contributionId,
    required int beneficiaryId,
  }) async {}

  @override
  Future<void> removeContributor(int contributorId) async {}

  @override
  Future<List<Participation>> myParticipation() async => <Participation>[];
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakePaymentsRepository repository,
  _FakeBeelsRepository? beels,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        beelDetailControllerProvider.overrideWith(
          () => _FakeBeelDetailController(),
        ),
        paymentsRepositoryProvider.overrideWithValue(repository),
        beelsRepositoryProvider
            .overrideWithValue(beels ?? _FakeBeelsRepository()),
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

  testWidgets(
      'Pay now shows only for payable contributors and shares the '
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

    await tester.ensureVisible(find.text('Pay now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(repository.initializedIds, ['JYLCWKtfdHVzihITWPSq']);
    expect(sharedTexts, ['https://checkout.flutterwave.com/pay/abc']);
  });

  testWidgets('failed initialization surfaces the API message', (tester) async {
    final repository = _FakePaymentsRepository();
    repository.initializeError =
        const ApiException('No pending deposit', statusCode: 400);

    await _pump(tester, repository: repository);

    await tester.ensureVisible(find.text('Pay now'));
    await tester.pumpAndSettle();
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

    await tester.ensureVisible(find.text('Pay now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(find.text('Payment link unavailable. Try again.'), findsOneWidget);
  });
  testWidgets('auto-debit activation posts the saved details and shows the '
      'confirmation account', (tester) async {
    final repository = _FakePaymentsRepository();
    final beels = _FakeBeelsRepository();
    await _pump(tester, repository: repository, beels: beels);

    await tester.ensureVisible(find.text('Set up auto-debit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up auto-debit'));
    // The action stays busy until the sheet closes, so settle only the
    // sheet's entry animation instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(beels.activations, hasLength(1));
    expect(beels.activations.single.identifier, 'nCFf1kFMUyCWgZ7iIAEz');
    expect(beels.activations.single.bankCode, '076');
    expect(beels.activations.single.accountNumber, '9016323384');

    expect(find.text('Automated collection'), findsOneWidget);
    expect(find.text('9016323384'), findsOneWidget);
    expect(find.text('Polaris Bank Limited'), findsOneWidget);
    expect(find.text('2026-09-23 20:26:55'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Automated collection'), findsNothing);
  });

  testWidgets('active auto-debit shows the chip instead of the action',
      (tester) async {
    await _pump(
      tester,
      repository: _FakePaymentsRepository(),
      beels: _FakeBeelsRepository(),
    );

    expect(find.text('Auto-debit on'), findsOneWidget);
    // Ada still has a pending activation.
    expect(find.text('Set up auto-debit'), findsOneWidget);
    expect(find.text('Show account'), findsNothing);
  });
}

