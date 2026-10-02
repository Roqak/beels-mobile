import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/payments/data/payments_repository.dart';

class _FakeApiClient implements ApiClient {
  final Map<String, Object Function()> handlers = {};
  final List<({String path, Object? body})> calls = [];

  Object _respond(String path) {
    final handler = handlers[path];
    if (handler == null) {
      throw ApiException('Unexpected call to $path', statusCode: 0);
    }
    return handler();
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((path: path, body: query));
    return _respond(path);
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }
}

void main() {
  late _FakeApiClient client;
  late PaymentsRepository repository;

  setUp(() {
    client = _FakeApiClient();
    repository = PaymentsRepository(client);
  });

  group('getBanks', () {
    test('parses the banks envelope', () async {
      client.handlers['/get-banks'] = () => {
            'statusCode': 200,
            'data': {
              'banks': [
                {
                  'bank_name': 'Guaranty Trust Bank',
                  'bank_cbn_code': '058',
                  'bank_nip_code': '058152036',
                  'logo_url': 'https://cdn/gtb.png',
                },
                {'bank_name': 'Access Bank', 'bank_cbn_code': '044'},
              ],
            },
          };

      final banks = await repository.getBanks();

      expect(banks, hasLength(2));
      expect(banks.first.name, 'Guaranty Trust Bank');
      expect(banks.first.cbnCode, '058');
      expect(banks.first.nipCode, '058152036');
      expect(banks.first.logoUrl, 'https://cdn/gtb.png');
      expect(
        client.calls.single.path,
        '/get-banks',
      );
      expect(client.calls.single.body, {'pwa_enabled_only': 'false'});
    });

    test('returns an empty list when the payload is not a list', () async {
      client.handlers['/get-banks'] = () => {
            'statusCode': 200,
            'data': {'banks': null},
          };

      expect(await repository.getBanks(), isEmpty);
    });
  });

  group('listMandates', () {
    test('parses the mandate envelope rows', () async {
      client.handlers['/mandate'] = () => {
            'statusCode': 200,
            'data': [
              {
                'id': 7,
                'account_number': '0123456789',
                'bank_code': '058',
                'bank_name': 'Guaranty Trust Bank',
                'status': 'ACTIVE',
                'created_at': '2026-01-02T03:04:05.000Z',
              },
              'garbage',
            ],
          };

      final mandates = await repository.listMandates();

      expect(mandates, hasLength(2));
      expect(mandates.first.id, 7);
      expect(mandates.first.isActive, isTrue);
      expect(mandates.first.bankName, 'Guaranty Trust Bank');
      expect(mandates.first.createdAt, isNotNull);
      expect(mandates.last.accountNumber, '');
    });
  });

  group('nameEnquiry', () {
    test('sends account and bank code, returns the account name', () async {
      client.handlers['/mandate/name-enquiry'] = () => {
            'statusCode': 200,
            'data': {'account_name': 'ADA LOVELACE'},
          };

      final name = await repository.nameEnquiry(
        accountNumber: '0123456789',
        bankCode: '058',
      );

      expect(name, 'ADA LOVELACE');
      expect(client.calls.single.body, {
        'account_number': '0123456789',
        'bank_code': '058',
      });
    });

    test('returns an empty string when the name is missing', () async {
      client.handlers['/mandate/name-enquiry'] = () => {
            'statusCode': 200,
            'data': null,
          };

      expect(
        await repository.nameEnquiry(
            accountNumber: '0123456789', bankCode: '058'),
        '',
      );
    });
  });

  test('setupMandate posts the full payload', () async {
    client.handlers['/mandate/setup'] = () => {'statusCode': 200};

    await repository.setupMandate(
      firstName: ' Ada ',
      lastName: 'Lovelace',
      email: 'ada@beels.ng',
      phoneNumber: '08012345678',
      accountNumber: '0123456789',
      bankName: 'Guaranty Trust Bank',
      bankCode: '058',
      bvn: '12345678901',
    );

    expect(client.calls.single.path, '/mandate/setup');
    expect(client.calls.single.body, {
      'first_name': ' Ada ',
      'last_name': 'Lovelace',
      'email': 'ada@beels.ng',
      'phone_number': '08012345678',
      'account_number': '0123456789',
      'bank_name': 'Guaranty Trust Bank',
      'bank_code': '058',
      'bvn': '12345678901',
    });
  });

  test('revokeMandate deletes the mandate path', () async {
    client.handlers['/mandate/7'] = () => {'statusCode': 200};

    await repository.revokeMandate(7);

    expect(client.calls.single.path, '/mandate/7');
  });

  group('initializePayment', () {
    test('posts the payment id and returns the checkout URL', () async {
      client.handlers['/payment/initialize'] = () => {
            'statusCode': 200,
            'data': {'url': 'https://checkout.flutterwave.com/pay/abc'},
          };

      final url = await repository.initializePayment('JYLCWKtfdHVzihITWPSq');

      expect(url, 'https://checkout.flutterwave.com/pay/abc');
      expect(
        client.calls.single.body,
        {'payment_id': 'JYLCWKtfdHVzihITWPSq'},
      );
    });

    test('returns an empty string when the URL is missing', () async {
      client.handlers['/payment/initialize'] = () => {
            'statusCode': 200,
            'data': {'status': 'pending'},
          };

      expect(await repository.initializePayment('x'), '');
    });
  });

  group('getPaymentOptions', () {
    test('parses options with transfer and debit accounts', () async {
      client.handlers['/contributions/pay/PID/options'] = () => {
            'statusCode': 200,
            'data': {
              'contributor': {'first_name': 'Ada'},
              'beel': {'name': 'Rent in Advance'},
              'amount_due': 30000,
              'amount_paid': 10000,
              'transfer': {
                'bank_name': 'GTBank',
                'account_number': '0123456789',
                'reference': 'PID',
              },
              'direct_debit': {
                'available': true,
                'accounts': [
                  {
                    'id': 5,
                    'bank_name': 'GTBank',
                    'account_number_masked': '••••6789',
                  },
                  {'id': 6},
                ],
              },
            },
          };

      final options = await repository.getPaymentOptions('PID');

      expect(options.beelName, 'Rent in Advance');
      expect(options.contributorFirstName, 'Ada');
      expect(options.amountDue, 30000);
      expect(options.amountPaid, 10000);
      expect(options.outstanding, 20000);
      expect(options.transferBankName, 'GTBank');
      expect(options.transferAccountNumber, '0123456789');
      expect(options.transferReference, 'PID');
      expect(options.directDebitAvailable, isTrue);
      expect(options.debitAccounts, hasLength(2));
      expect(options.debitAccounts.first.id, 5);
      expect(options.debitAccounts.first.bankName, 'GTBank');
      expect(options.debitAccounts.first.accountNumberMasked, '••••6789');
      // Accounts without bank names degrade, they do not crash.
      expect(options.debitAccounts.last.bankName, 'Linked account');
    });

    test('throws when the payment reference is unknown', () async {
      client.handlers['/contributions/pay/BAD/options'] = () => {'data': null};

      await expectLater(
        repository.getPaymentOptions('BAD'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('payByDirectDebit', () {
    test('posts the mandate id and returns the receipt', () async {
      client.handlers['/contributions/pay/PID/direct-debit'] = () => {
            'statusCode': 200,
            'message': 'Payment received. The account was debited and this Beel is updated.',
            'data': {'reference': 'debit-ref-1', 'amount': 20000},
          };

      final receipt = await repository.payByDirectDebit('PID', 5);

      expect(client.calls.last.body, {'mandate_id': 5});
      expect(receipt.reference, 'debit-ref-1');
      expect(receipt.amount, 20000);
      expect(receipt.message, contains('Payment received'));
    });
  });
}
