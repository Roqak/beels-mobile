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

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String value) async {
  await tester.enterText(_field(label), value);
  await tester.pump();
}

Future<void> _basics(WidgetTester tester,
    {String name = 'Family rent', String amount = '60000'}) async {
  await tester.enterText(find.byType(TextField).at(0), name);
  await tester.enterText(find.byType(TextField).at(1), amount);
  await tester.pump();
}

/// Opens the person sheet from the page button (the first "Add person").
Future<void> _openPersonSheet(WidgetTester tester) async {
  await tester.tap(find.text('Add person').first);
  await tester.pumpAndSettle();
}

Future<void> _fillPerson(
  WidgetTester tester, {
  String first = 'Ada',
  String last = 'Obi',
  String phone = '08012345678',
  String email = 'ada@beels.test',
  String? amount,
}) async {
  await _enter(tester, 'First name', first);
  await _enter(tester, 'Last name', last);
  await _enter(tester, 'Phone number', phone);
  await _enter(tester, 'Email', email);
  if (amount != null) {
    await _enter(tester, 'Amount this person pays', amount);
  }
}

/// Adds one person end to end (sheet open, filled, saved).
Future<void> _addPerson(
  WidgetTester tester, {
  String first = 'Ada',
  String last = 'Obi',
  String phone = '08012345678',
  String email = 'ada@beels.test',
  String? amount,
}) async {
  await _openPersonSheet(tester);
  await _fillPerson(tester,
      first: first, last: last, phone: phone, email: email, amount: amount);
  // Only the sheet's primary button is a plain FilledButton.
  await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
  await tester.pumpAndSettle();
}

Future<void> _addBankAccount(
  WidgetTester tester, {
  String bank = 'GTBank',
  String account = '0123456789',
}) async {
  await tester.tap(find.text('Add payout account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose a bank'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(bank));
  await tester.pumpAndSettle();
  await _enter(tester, 'Account number', account);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
  await tester.pumpAndSettle();
}

/// Steps 1-2 with a target, ready for the people step.
Future<void> _toPeople(WidgetTester tester, {String amount = '60000'}) async {
  await _basics(tester, amount: amount);
  await _tapContinue(tester);
  await _tapContinue(tester);
}

/// A complete closed beel up to the payout step.
Future<void> _toPayout(WidgetTester tester, {String amount = '60000'}) async {
  await _toPeople(tester, amount: amount);
  await _addPerson(tester, amount: amount);
  await _tapContinue(tester);
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

  testWidgets('the mode choices use plain words', (tester) async {
    await _pump(tester);

    expect(find.text('I choose the people'), findsOneWidget);
    expect(find.text('Anyone with a link'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
    expect(find.text('Open link'), findsNothing);
  });

  testWidgets('the target is formatted with thousands separators as typed',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).at(1), '1250000');
    await tester.pump();

    expect(find.text('1,250,000'), findsOneWidget);
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

  group('people', () {
    testWidgets('adding a person opens a sheet pre-filled with what is left',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');

      await _openPersonSheet(tester);

      expect(find.text('Add person'), findsWidgets);
      // The amount box starts at the whole remaining amount.
      expect(
        tester
            .widget<TextField>(_field('Amount this person pays'))
            .controller!
            .text,
        '60,000',
      );
    });

    testWidgets('the running total is pinned and updates as people are added',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');
      expect(find.text('₦0 of ₦60,000 assigned'), findsOneWidget);

      await _addPerson(tester, amount: '40000');

      expect(find.text('Ada Obi'), findsOneWidget);
      expect(find.text('₦40,000 of ₦60,000 assigned'), findsOneWidget);
      expect(find.text('₦20,000 left'), findsOneWidget);
    });

    testWidgets('the sheet explains what is missing and does not save',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester);
      await _openPersonSheet(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNWidgets(2)); // first + last
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('At least 11 digits'), findsOneWidget);
      // Still in the sheet; nobody was added.
      expect(find.text('New person'), findsNothing);
      expect(find.text('₦0 of ₦60,000 assigned'), findsOneWidget);
    });

    testWidgets('save and add another keeps the sheet open for the next person',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');
      await _openPersonSheet(tester);

      await _fillPerson(tester, amount: '40000');
      await tester.tap(find.text('Save and add another'));
      await tester.pumpAndSettle();

      expect(find.text('Added Ada Obi'), findsOneWidget);
      // Fields cleared; amount offers what is left.
      expect(
          tester.widget<TextField>(_field('First name')).controller!.text, '');
      expect(
        tester
            .widget<TextField>(_field('Amount this person pays'))
            .controller!
            .text,
        '20,000',
      );

      await _fillPerson(tester,
          first: 'Bode',
          last: 'Aliu',
          phone: '08023456789',
          email: 'b@beels.test');
      await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Obi'), findsOneWidget);
      expect(find.text('Bode Aliu'), findsOneWidget);
      expect(find.text('All set'), findsOneWidget);
    });

    testWidgets('tapping a person edits them, and they can be removed',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');
      await _addPerson(tester, amount: '60000');

      await tester.tap(find.text('Ada Obi'));
      await tester.pumpAndSettle();
      expect(find.text('Edit person'), findsOneWidget);
      await _enter(tester, 'Amount this person pays', '30000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('₦30,000 of ₦60,000 assigned'), findsOneWidget);

      await tester.tap(find.text('Ada Obi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove person'));
      await tester.pumpAndSettle();
      expect(find.text('Ada Obi'), findsNothing);
      expect(find.text('₦0 of ₦60,000 assigned'), findsOneWidget);
    });

    testWidgets('split equally shares the target between everyone',
        (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');
      await _addPerson(tester, amount: '10000');
      await _addPerson(tester,
          first: 'Bode',
          last: 'Aliu',
          phone: '08023456789',
          email: 'b@beels.test',
          amount: '10000');

      await tester.tap(find.text('Split ₦60,000 equally between 2'));
      await tester.pumpAndSettle();

      expect(find.text('₦60,000 of ₦60,000 assigned'), findsOneWidget);
      expect(find.text('All set'), findsOneWidget);
    });

    testWidgets('a mismatch is explained on Continue', (tester) async {
      await _pump(tester);
      await _toPeople(tester, amount: '60000');
      await _addPerson(tester, amount: '40000');

      await _tapContinue(tester);

      expect(find.text('Amounts add up to ₦40,000, but the target is ₦60,000'),
          findsOneWidget);
      expect(find.text('Step 3 of 5'), findsOneWidget);
    });

    testWidgets('a person can be added from contacts', (tester) async {
      await _pump(tester);
      await _toPeople(tester);

      await tester.tap(find.text('From contacts').first);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_field('First name')).controller!.text,
          'Bode');
      expect(tester.widget<TextField>(_field('Phone number')).controller!.text,
          '08023456789');
    });
  });

  group('payout', () {
    testWidgets('starts with one clear call to action', (tester) async {
      await _pump(tester);
      await _toPayout(tester);

      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Add payout account'), findsOneWidget);
    });

    testWidgets('bank check fills the name and the account becomes a row',
        (tester) async {
      final h = await _pump(tester);
      await _toPayout(tester);

      await tester.tap(find.text('Add payout account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GTBank'));
      await tester.pumpAndSettle();
      await _enter(tester, 'Account number', '0123456789');
      await tester.pumpAndSettle();

      expect(h.payments.enquiries, 1);
      expect(find.text('Verified: ADA OBI'), findsOneWidget);
      expect(tester.widget<TextField>(_field('Account name')).controller!.text,
          'ADA OBI');

      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('ADA OBI'), findsOneWidget);
      expect(find.text('GTBank · •••• 6789'), findsOneWidget);
      expect(find.text('Add payout account'), findsNothing);
    });

    testWidgets('a failed bank check never blocks: the name can be typed',
        (tester) async {
      await _pump(tester, accountName: 'FAIL');
      await _toPayout(tester);

      await tester.tap(find.text('Add payout account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GTBank'));
      await tester.pumpAndSettle();
      await _enter(tester, 'Account number', '0123456789');
      await tester.pumpAndSettle();

      expect(
          find.textContaining('could not verify this account'), findsOneWidget);
      await _enter(tester, 'Account name', 'Ada Obi');
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();
      await _tapContinue(tester);

      expect(find.text('Step 5 of 5'), findsOneWidget);
    });

    testWidgets('the sheet lists what is missing and does not save',
        (tester) async {
      await _pump(tester);
      await _toPayout(tester);
      await tester.tap(find.text('Add payout account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a bank'), findsWidgets);
      expect(find.text('Enter the 10-digit account number'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget); // name
      expect(find.text('Add payout account'), findsOneWidget); // still empty
    });

    testWidgets('a second account defaults to half, and the total is pinned',
        (tester) async {
      await _pump(tester);
      await _toPayout(tester);
      await _addBankAccount(tester);

      await tester.tap(find.text('Split to another account'));
      await tester.pumpAndSettle();
      // Half the target is suggested for the new account.
      expect(
        tester
            .widget<TextField>(_field('Amount for this account'))
            .controller!
            .text,
        '30,000',
      );
      await tester.tap(find.text('Choose a bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Access Bank'));
      await tester.pumpAndSettle();
      await _enter(tester, 'Account number', '2034567890');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      // The first account was given the rest, so the two add up.
      expect(find.text('₦60,000 of ₦60,000 paid out'), findsOneWidget);
      expect(find.text('₦30,000'), findsNWidgets(2));
      expect(find.text('All set'), findsOneWidget);
    });
  });

  testWidgets('full closed flow: review, create, finish', (tester) async {
    final h = await _pump(tester);
    await _basics(tester, name: 'Family rent', amount: '60000');
    await _tapContinue(tester);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Friday'));
    await tester.pumpAndSettle();
    await _tapContinue(tester);
    await _addPerson(tester, amount: '60000');
    await _tapContinue(tester);
    await _addBankAccount(tester);
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
    expect(b['amount'], 60000); // a single payout takes the whole target

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

    await _addBankAccount(tester, bank: 'Access Bank', account: '2034567890');
    await _tapContinue(tester);
    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();

    expect(h.beels.open!['expected_contributors'], 3);
    expect(h.beels.open!.containsKey('amount_per_contributor'), isFalse);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('View beel'), findsOneWidget);
  });

  testWidgets('a failed create keeps you on review with the reason',
      (tester) async {
    final h = await _pump(tester);
    h.beels.failWith =
        const ApiException('Beneficiary Allocation Mismatch', statusCode: 401);
    await _toPayout(tester, amount: '1000');
    await _addBankAccount(tester);
    await _tapContinue(tester);

    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();

    expect(find.text('Beneficiary Allocation Mismatch'), findsOneWidget);
    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(find.text('Your beel is live'), findsNothing);
  });

  testWidgets('leaving with unsaved input asks first', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Half done');
    await tester.pump();

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
