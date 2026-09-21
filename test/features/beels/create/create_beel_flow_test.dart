import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/contacts/contact_picker.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/screens/create_beel_screen.dart';
import 'package:beels_mobile/features/payments/controllers/mandates_controller.dart';
import 'package:beels_mobile/features/payments/data/payments_repository.dart';
import 'package:beels_mobile/features/payments/models/bank.dart';

class _FakeBeels implements BeelsRepository {
  Map<String, dynamic>? closed;
  Map<String, dynamic>? open;
  Object? failWith;

  @override
  Future<Contribution> create({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) async {
    if (failWith != null) throw failWith!;
    closed = BeelsRepository.buildClosedPayload(
      name: name,
      amount: amount,
      recurrenceType: recurrenceType,
      dayOfWeek: dayOfWeek,
      dayOfMonth: dayOfMonth,
      contributors: contributors,
      beneficiaries: beneficiaries,
    );
    // The real backend returns no id for closed beels.
    return Contribution(name: name);
  }

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
  }) async {
    if (failWith != null) throw failWith!;
    open = BeelsRepository.buildOpenPayload(
      name: name,
      amount: amount,
      amountPerContributor: amountPerContributor,
      expectedContributors: expectedContributors,
      recurrenceType: recurrenceType,
      dayOfWeek: dayOfWeek,
      dayOfMonth: dayOfMonth,
      beneficiaries: beneficiaries,
    );
    return Contribution(
      id: 9,
      name: name,
      contributionMode: 'open_link',
      paymentLinkToken: 'tok_123',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePayments implements PaymentsRepository {
  _FakePayments({this.accountName = 'ADA OBI'});

  final String accountName;
  int enquiries = 0;

  @override
  Future<String> nameEnquiry({
    required String accountNumber,
    required String bankCode,
  }) async {
    enquiries++;
    if (accountName == 'FAIL') {
      throw const ApiException('down', statusCode: 500);
    }
    return accountName;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePicker implements ContactPicker {
  @override
  Future<PickedContact?> pick() async => const PickedContact(
        firstName: 'Bode',
        lastName: 'Aliu',
        phone: '08023456789',
        email: 'bode@beels.test',
      );
}

// Monday 21 Sep 2026.
final _now = DateTime(2026, 9, 21);

class _Harness {
  _Harness({String accountName = 'ADA OBI'})
      : beels = _FakeBeels(),
        payments = _FakePayments(accountName: accountName);

  final _FakeBeels beels;
  final _FakePayments payments;
  final List<String> visited = [];
}

Future<_Harness> _pump(WidgetTester tester,
    {String accountName = 'ADA OBI'}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final h = _Harness(accountName: accountName);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/create'),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/create',
        builder: (_, __) => CreateBeelScreen(now: _now),
      ),
      GoRoute(
        path: '/beels',
        builder: (_, __) => const Scaffold(body: Text('BEELS_LIST')),
      ),
      GoRoute(
        path: '/beels/:id',
        builder: (_, s) =>
            Scaffold(body: Text('BEEL_${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        beelsRepositoryProvider.overrideWithValue(h.beels),
        paymentsRepositoryProvider.overrideWithValue(h.payments),
        banksProvider.overrideWith((ref) async => const [
              Bank(id: 1, name: 'GTBank', cbnCode: '058'),
              Bank(id: 2, name: 'Access Bank', cbnCode: '044'),
            ]),
        contactPickerProvider.overrideWithValue(_FakePicker()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

/// Fields are found by their label above them (FormBlock), so locate the
/// TextField that follows a label text.
Finder _fieldAfter(String label) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(TextField),
    );

Future<void> _type(WidgetTester tester, String label, String value) async {
  final f = _fieldAfter(label);
  await tester.ensureVisible(f.first);
  await tester.enterText(f.first, value);
  await tester.pump();
}

Future<void> _basics(WidgetTester tester,
    {String name = 'Family rent', String amount = '60000'}) async {
  await _type(tester, 'Name your beel', name);
  final big = find.byType(TextField).at(1);
  await tester.enterText(big, amount);
  await tester.pump();
}

void main() {
  testWidgets('step 1 blocks Continue and explains what is missing',
      (tester) async {
    await _pump(tester);
    expect(find.text('Step 1 of 5'), findsOneWidget);

    await _tapContinue(tester);

    expect(find.text('Give your beel a name'), findsOneWidget);
    expect(find.text('Enter the target amount'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('the mode choices use plain words and switch the flow',
      (tester) async {
    await _pump(tester);

    expect(find.text('I choose the people'), findsOneWidget);
    expect(find.text('Anyone with a link'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
    expect(find.text('Open link'), findsNothing);
  });

  testWidgets('schedule explains the result and the next date', (tester) async {
    await _pump(tester);
    await _basics(tester);
    await _tapContinue(tester);

    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(find.text('One time only'), findsOneWidget);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Friday'));
    await tester.pumpAndSettle();

    expect(find.text('Every Friday'), findsOneWidget);
    expect(find.text('Next collection: Friday, 25 Sep'), findsOneWidget);
  });

  testWidgets('going back keeps what was entered', (tester) async {
    await _pump(tester);
    await _basics(tester, name: 'Ajo circle');
    await _tapContinue(tester);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Ajo circle'), findsOneWidget);
  });

  testWidgets('people step shows live totals and can split equally',
      (tester) async {
    await _pump(tester);
    await _basics(tester, amount: '60000');
    await _tapContinue(tester);
    await _tapContinue(tester); // schedule

    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(find.text('₦0 of ₦60,000 assigned'), findsOneWidget);

    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    expect(find.text('Split ₦60,000 equally between 2'), findsOneWidget);

    await tester.tap(find.text('Split ₦60,000 equally between 2'));
    await tester.pumpAndSettle();

    expect(find.text('₦60,000 of ₦60,000 assigned'), findsOneWidget);
    expect(find.text('Perfect. Every naira is assigned.'), findsOneWidget);
  });

  testWidgets('a mismatch is explained on Continue, with the person flagged',
      (tester) async {
    await _pump(tester);
    await _basics(tester, amount: '60000');
    await _tapContinue(tester);
    await _tapContinue(tester);

    await _type(tester, 'First name', 'Ada');
    await _type(tester, 'Last name', 'Obi');
    await _type(tester, 'Phone number', '08012345678');
    await _type(tester, 'Email', 'ada@beels.test');
    await _type(tester, 'Amount this person pays', '40000');
    await _tapContinue(tester);

    expect(find.text('₦40,000 of ₦60,000 assigned'), findsOneWidget);
    expect(find.text('₦20,000 left to go'), findsOneWidget);
    expect(find.text('Amounts add up to ₦40,000, but the target is ₦60,000'),
        findsOneWidget);
    expect(find.text('Step 3 of 5'), findsOneWidget);
  });

  testWidgets('a person can be added from contacts', (tester) async {
    await _pump(tester);
    await _basics(tester);
    await _tapContinue(tester);
    await _tapContinue(tester);

    await tester.tap(find.text('From contacts').last);
    await tester.pumpAndSettle();

    expect(find.text('Bode Aliu'), findsOneWidget);
  });

  testWidgets(
      'full closed flow: bank check fills the name, review, create, finish',
      (tester) async {
    final h = await _pump(tester);
    await _basics(tester, name: 'Family rent', amount: '60000');
    await _tapContinue(tester);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Friday'));
    await tester.pumpAndSettle();
    await _tapContinue(tester);

    await _type(tester, 'First name', 'Ada');
    await _type(tester, 'Last name', 'Obi');
    await _type(tester, 'Phone number', '08012345678');
    await _type(tester, 'Email', 'ada@beels.test');
    await _type(tester, 'Amount this person pays', '60000');
    await _tapContinue(tester);

    expect(find.text('Step 4 of 5'), findsOneWidget);
    // Pick a bank from the searchable sheet, then type the account.
    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GTBank'));
    await tester.pumpAndSettle();
    await _type(tester, 'Account number', '0123456789');
    await tester.pumpAndSettle();

    expect(h.payments.enquiries, 1);
    expect(find.text('Verified: ADA OBI'), findsOneWidget);
    // The verified name was filled in for the user.
    expect(find.text('ADA OBI'), findsWidgets);
    await _tapContinue(tester);

    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(find.text('Family rent'), findsOneWidget);
    expect(find.text('Every Friday · next 25 Sep'), findsOneWidget);
    expect(find.text('GTBank · •••• 6789'), findsOneWidget);

    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();

    final payload = h.beels.closed!;
    expect(payload['name'], 'Family rent');
    expect(payload['amount'], 60000);
    expect(payload['recurrence_type'], 'weekly');
    expect(payload['day_of_week'], 'friday');
    expect((payload['contributors'] as List).single['amount'], 60000);
    final b = (payload['beneficiaries'] as List).single as Map;
    expect(b['bank_code'], '058');
    expect(b['account_number'], '0123456789');
    expect(b['amount'], 60000); // single payout defaults to the whole target

    expect(find.text('Your beel is live'), findsOneWidget);
    expect(find.text('View my beels'), findsOneWidget);
    expect(find.text('Share link'), findsNothing);

    await tester.tap(find.text('View my beels'));
    await tester.pumpAndSettle();
    expect(find.text('BEELS_LIST'), findsOneWidget);
  });

  testWidgets('open-link flow prices each person live and ends with a link',
      (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Anyone with a link'));
    await tester.pumpAndSettle();
    await _basics(tester, name: 'Office party', amount: '60000');
    await _tapContinue(tester);
    await _tapContinue(tester);

    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(find.text('Each person pays'), findsOneWidget);
    expect(find.text('₦30,000'), findsOneWidget); // 60,000 / 2 people

    await tester.tap(find.bySemanticsLabel('More people'));
    await tester.pumpAndSettle();
    expect(find.text('₦20,000'), findsOneWidget); // 60,000 / 3
    await _tapContinue(tester);

    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Access Bank'));
    await tester.pumpAndSettle();
    await _type(tester, 'Account number', '2034567890');
    await tester.pumpAndSettle();
    await _tapContinue(tester);

    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();

    expect(h.beels.open!['expected_contributors'], 3);
    expect(h.beels.open!.containsKey('amount_per_contributor'), isFalse);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('View beel'), findsOneWidget);
  });

  testWidgets('a failed bank check never blocks: the name can be typed',
      (tester) async {
    await _pump(tester, accountName: 'FAIL');
    await _basics(tester);
    await _tapContinue(tester);
    await _tapContinue(tester);
    await _type(tester, 'First name', 'Ada');
    await _type(tester, 'Last name', 'Obi');
    await _type(tester, 'Phone number', '08012345678');
    await _type(tester, 'Email', 'ada@beels.test');
    await _type(tester, 'Amount this person pays', '60000');
    await _tapContinue(tester);

    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GTBank'));
    await tester.pumpAndSettle();
    await _type(tester, 'Account number', '0123456789');
    await tester.pumpAndSettle();

    expect(
        find.textContaining('could not verify this account'), findsOneWidget);
    await _type(tester, 'Account name', 'Ada Obi');
    await _tapContinue(tester);
    expect(find.text('Step 5 of 5'), findsOneWidget);
  });

  testWidgets('several payout accounts must add up, with a live bar',
      (tester) async {
    await _pump(tester);
    await _basics(tester, amount: '60000');
    await _tapContinue(tester);
    await _tapContinue(tester);
    await _type(tester, 'First name', 'Ada');
    await _type(tester, 'Last name', 'Obi');
    await _type(tester, 'Phone number', '08012345678');
    await _type(tester, 'Email', 'ada@beels.test');
    await _type(tester, 'Amount this person pays', '60000');
    await _tapContinue(tester);

    await tester.tap(find.text('Split between another account'));
    await tester.pumpAndSettle();

    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
    expect(find.text('Amount for this account'), findsNWidgets(2));
  });

  testWidgets('a failed create keeps you on review with the reason',
      (tester) async {
    final h = await _pump(tester);
    h.beels.failWith =
        const ApiException('Beneficiary Allocation Mismatch', statusCode: 401);
    await _basics(tester, amount: '1000');
    await _tapContinue(tester);
    await _tapContinue(tester);
    await _type(tester, 'First name', 'Ada');
    await _type(tester, 'Last name', 'Obi');
    await _type(tester, 'Phone number', '08012345678');
    await _type(tester, 'Email', 'ada@beels.test');
    await _type(tester, 'Amount this person pays', '1000');
    await _tapContinue(tester);
    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GTBank'));
    await tester.pumpAndSettle();
    await _type(tester, 'Account number', '0123456789');
    await tester.pumpAndSettle();
    await _tapContinue(tester);

    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();

    expect(find.text('Beneficiary Allocation Mismatch'), findsOneWidget);
    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(find.text('Your beel is live'), findsNothing);
  });

  testWidgets('leaving with unsaved input asks first', (tester) async {
    await _pump(tester);
    await _type(tester, 'Name your beel', 'Half done');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this beel?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('leaving an untouched form does not nag', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard this beel?'), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
  });
}
