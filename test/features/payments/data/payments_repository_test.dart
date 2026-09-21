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
}
