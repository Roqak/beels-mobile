import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/payments/controllers/mandate_setup_controller.dart';
import 'package:beels_mobile/features/payments/data/payments_repository.dart';
import 'package:beels_mobile/features/payments/models/bank.dart';
import 'package:beels_mobile/features/payments/models/payment_mandate.dart';
import 'package:beels_mobile/features/payments/screens/mandate_setup_screen.dart';
import 'package:beels_mobile/features/auth/widgets/fields.dart';

class _FakePaymentsRepository implements PaymentsRepository {
  Map<String, dynamic>? setupBody;
  Object? setupError;
  String enquiryResult = 'ADA LOVELACE';

  int get setupCalls => setupBody == null ? 0 : 1;

  @override
  Future<String> nameEnquiry({
    required String accountNumber,
    required String bankCode,
  }) async =>
      enquiryResult;

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
    final error = setupError;
    if (error != null) throw error;
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
  }

  @override
  Future<List<Bank>> getBanks() async => const [
        Bank(name: 'Guaranty Trust Bank', cbnCode: '058'),
        Bank(name: 'Access Bank', cbnCode: '044'),
      ];

  @override
  Future<List<PaymentMandate>> listMandates() async => <PaymentMandate>[];

  @override
  Future<void> revokeMandate(int id) async {}

  @override
  Future<String> initializePayment(String paymentId) async => '';
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakePaymentsRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        paymentsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: MandateSetupScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final finder = find.widgetWithText(BeelsTextField, label);
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.enterText(finder, value);
}

void main() {
  testWidgets('verify flow advances to personal details with account name',
      (tester) async {
    final repository = _FakePaymentsRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Choose your bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guaranty Trust Bank'));
    await tester.pumpAndSettle();

    await _enter(tester, 'Account number', '0123456789');
    await tester.tap(find.text('Verify account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ADA LOVELACE'), findsOneWidget);
    expect(find.text('Your details'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
  });

  testWidgets('invalid BVN blocks submission', (tester) async {
    final repository = _FakePaymentsRepository();
    await _pump(tester, repository: repository);

    // Jump straight to the personal step through the controller.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MandateSetupScreen)),
    );
    final controller = container.read(mandateSetupControllerProvider.notifier);
    controller.selectBank(const Bank(name: 'GTB', cbnCode: '058'));
    await controller.verifyAccount(accountNumber: '0123456789');
    await tester.pumpAndSettle();

    await _enter(tester, 'First name', 'Ada');
    await _enter(tester, 'Last name', 'Lovelace');
    await _enter(tester, 'Email', 'ada@beels.ng');
    await _enter(tester, 'Phone number', '08012345678');
    await _enter(tester, 'Bank Verification Number (BVN)', '12345');
    await tester.ensureVisible(find.text('Set up mandate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up mandate'));
    await tester.pumpAndSettle();

    expect(find.text('BVN must be 11 digits'), findsOneWidget);
    expect(repository.setupCalls, 0);
  });
}
