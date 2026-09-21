import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/payments/controllers/mandate_setup_controller.dart';
import 'package:beels_mobile/features/payments/data/payments_repository.dart';
import 'package:beels_mobile/features/payments/models/bank.dart';
import 'package:beels_mobile/features/payments/models/payment_mandate.dart';

class _FakePaymentsRepository implements PaymentsRepository {
  int nameEnquiryCalls = 0;
  String enquiryResult = 'ADA LOVELACE';
  Object? enquiryError;
  Map<String, dynamic>? setupBody;
  Object? setupError;

  @override
  Future<List<Bank>> getBanks() async => <Bank>[];

  @override
  Future<List<PaymentMandate>> listMandates() async => <PaymentMandate>[];

  @override
  Future<String> nameEnquiry({
    required String accountNumber,
    required String bankCode,
  }) async {
    nameEnquiryCalls++;
    final error = enquiryError;
    if (error != null) throw error;
    return enquiryResult;
  }

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
  }) async {
    setupBody = {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'account_number': accountNumber,
      'bank_name': bankName,
      'bank_code': bankCode,
      'bvn': bvn,
    };
    final error = setupError;
    if (error != null) throw error;
  }

  @override
  Future<void> revokeMandate(int id) async {}

  @override
  Future<String> initializePayment(String paymentId) async => '';
}

void main() {
  late _FakePaymentsRepository repository;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      paymentsRepositoryProvider.overrideWithValue(repository),
    ]);
    // Keep the auto-dispose controller alive across test interactions.
    container.listen(mandateSetupControllerProvider, (_, __) {});
    return container;
  }

  setUp(() {
    repository = _FakePaymentsRepository();
  });

  test('selectBank requires a CBN code before verifying', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);

    controller.selectBank(const Bank(name: 'No-code bank'));
    expect(
      container.read(mandateSetupControllerProvider).canVerify('0123456789'),
      isFalse,
    );

    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    expect(
      container.read(mandateSetupControllerProvider).canVerify('0123456789'),
      isTrue,
    );
  });

  test('verifyAccount success stores the account name and advances',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));

    await controller.verifyAccount(accountNumber: '0123456789');

    final state = container.read(mandateSetupControllerProvider);
    expect(state.accountName, 'ADA LOVELACE');
    expect(state.accountNumber, '0123456789');
    expect(state.step, MandateSetupStep.personal);
    expect(state.error, isNull);
  });

  test('verifyAccount failure surfaces the API message and stays put',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    repository.enquiryError =
        const ApiException('Account not found', statusCode: 404);

    await controller.verifyAccount(accountNumber: '0123456789');

    final state = container.read(mandateSetupControllerProvider);
    expect(state.step, MandateSetupStep.details);
    expect(state.error, 'Account not found');
    expect(state.accountName, isNull);
  });

  test('backToAccount returns to the account step', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    await controller.verifyAccount(accountNumber: '0123456789');

    controller.backToAccount();

    expect(container.read(mandateSetupControllerProvider).step,
        MandateSetupStep.details);
  });

  test('submit posts trimmed personal details against the verified account',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    await controller.verifyAccount(accountNumber: '0123456789');

    await controller.submit(
      firstName: ' Ada ',
      lastName: 'Lovelace ',
      email: 'ada@beels.ng',
      phoneNumber: '08012345678',
      bvn: '12345678901',
    );

    expect(repository.setupBody, {
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'email': 'ada@beels.ng',
      'phone_number': '08012345678',
      'account_number': '0123456789',
      'bank_name': 'GTB',
      'bank_code': '058',
      'bvn': '12345678901',
    });
    expect(
      container.read(mandateSetupControllerProvider).submitting,
      isFalse,
    );
  });

  test('submit is a no-op when the BVN is not 11 digits', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    await controller.verifyAccount(accountNumber: '0123456789');

    await controller.submit(
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@beels.ng',
      phoneNumber: '08012345678',
      bvn: '12345',
    );

    expect(repository.setupBody, isNull);
  });

  test('submit rethrows repository errors and clears submitting', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    await controller.verifyAccount(accountNumber: '0123456789');
    repository.setupError = const ApiException('Mandate already exists',
        statusCode: 400);

    await expectLater(
      controller.submit(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@beels.ng',
        phoneNumber: '08012345678',
        bvn: '12345678901',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      container.read(mandateSetupControllerProvider).submitting,
      isFalse,
    );
  });
}