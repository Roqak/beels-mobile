import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';

void main() {
  group('BeelsRepository.buildClosedPayload', () {
    test('emits snake_case contributors and beneficiaries', () {
      final payload = BeelsRepository.buildClosedPayload(
        name: 'Family Savings',
        amount: 60000,
        recurrenceType: 'weekly',
        dayOfWeek: 'monday',
        contributors: [
          ContributorInput(
            firstName: 'Ada',
            lastName: 'Obi',
            email: 'ada@example.com',
            phoneNumber: '08012345678',
            amount: 60000,
          ),
        ],
        beneficiaries: [
          BeneficiaryInput(
            name: 'Mama',
            type: 'bank_transfer',
            accountNumber: '0123456789',
            bankCode: '058',
            amount: 60000,
          ),
        ],
      );

      expect(payload, {
        'name': 'Family Savings',
        'amount': 60000,
        'recurrence_type': 'weekly',
        'day_of_week': 'monday',
        'contributors': [
          {
            'first_name': 'Ada',
            'last_name': 'Obi',
            'email': 'ada@example.com',
            'phone_number': '08012345678',
            'amount': 60000,
          },
        ],
        'beneficiaries': [
          {
            'name': 'Mama',
            'type': 'bank_transfer',
            'account_number': '0123456789',
            'bank_code': '058',
            'amount': 60000,
          },
        ],
      });
    });

    test('sends day_of_week only for weekly recurrence', () {
      final payload = BeelsRepository.buildClosedPayload(
        name: 'B',
        amount: 1000,
        recurrenceType: 'daily',
        dayOfWeek: 'monday',
        dayOfMonth: 3,
        contributors: const [],
        beneficiaries: const [],
      );

      expect(payload.containsKey('day_of_week'), isFalse);
      expect(payload.containsKey('day_of_month'), isFalse);
      expect(payload['recurrence_type'], 'daily');
    });

    test('sends day_of_month only for monthly recurrence', () {
      final payload = BeelsRepository.buildClosedPayload(
        name: 'B',
        amount: 1000,
        recurrenceType: 'monthly',
        dayOfMonth: 15,
        contributors: const [],
        beneficiaries: const [],
      );

      expect(payload.containsKey('day_of_week'), isFalse);
      expect(payload['day_of_month'], 15);
    });
  });

  group('BeelsRepository.buildOpenPayload', () {
    test(
        'amount_per_contributor and expected_contributors are mutually exclusive',
        () {
      final perContributor = BeelsRepository.buildOpenPayload(
        name: 'Birthday Fund',
        amount: 25000,
        amountPerContributor: 2500,
        recurrenceType: 'one_time',
        beneficiaries: [
          BeneficiaryInput(name: 'Mama', type: 'airtime', amount: 25000),
        ],
      );

      expect(perContributor['amount_per_contributor'], 2500);
      expect(perContributor.containsKey('expected_contributors'), isFalse);

      final expected = BeelsRepository.buildOpenPayload(
        name: 'Birthday Fund',
        amount: 25000,
        expectedContributors: 10,
        recurrenceType: 'one_time',
        beneficiaries: [
          BeneficiaryInput(name: 'Mama', type: 'airtime', amount: 25000),
        ],
      );

      expect(expected['expected_contributors'], 10);
      expect(expected.containsKey('amount_per_contributor'), isFalse);
    });

    test('omits all null keys', () {
      final payload = BeelsRepository.buildOpenPayload(
        name: 'B',
        amount: 1000,
        recurrenceType: 'one_time',
        beneficiaries: const [],
      );

      expect(payload.keys, containsAll(['name', 'amount', 'recurrence_type']));
      expect(
        payload.keys.any(
          (key) => const [
            'amount_per_contributor',
            'expected_contributors',
            'day_of_week',
            'day_of_month',
          ].contains(key),
        ),
        isFalse,
      );
    });
  });

  group('BeelsRepository.parseListResponse', () {
    test('parses the paginated contributions envelope', () {
      final page = BeelsRepository.parseListResponse({
        'statusCode': 200,
        'message': 'OK',
        'data': [
          {
            'id': 1,
            'name': 'First',
            'status': 'active',
            'unit_amount': 5000,
            'occurrences': 12,
          },
          {
            'id': 2,
            'name': 'Second',
            'status': 'pending',
          },
        ],
        'current_page': 1,
        'per_page': 20,
        'from': 1,
        'to': 2,
        'total': 2,
        'last_page': 1,
        'next_page_url': null,
      });

      expect(page.items, hasLength(2));
      expect(page.page, 1);
      expect(page.perPage, 20);
      expect(page.total, 2);
      expect(page.lastPage, 1);
      expect(page.items.first.name, 'First');
      expect(page.items.first.unitAmount, 5000);
      expect(page.items.last.status, 'pending');
    });

    test('tolerates a malformed envelope', () {
      final page = BeelsRepository.parseListResponse(const {});

      expect(page.items, isEmpty);
      expect(page.page, 0);
      expect(page.total, 0);
      expect(page.lastPage, 0);
    });
  });
  group('invites', () {
    test('createInvite posts max_uses and parses the envelope', () async {
      final client = _FakeApiClient()
        ..handlers['/contributions/9/invites'] = () => {
              'statusCode': 201,
              'message': 'created',
              'data': {
                'token': 'abc123',
                'join_url':
                    'https://beels-frontend-production.up.railway.app/join/abc123',
                'share_amount': 250000,
                'max_uses': 5,
                'expires_at': '2026-10-03T10:00:00.000Z',
                'slots_left': 5,
              },
            };
      final repo = BeelsRepository(client);

      final invite = await repo.createInvite(contributionId: 9, maxUses: 5);

      expect(client.calls.single.path, '/contributions/9/invites');
      expect(client.calls.single.body, {'max_uses': 5});
      expect(invite.token, 'abc123');
      // Kobo from the API -> naira in the model layer.
      expect(invite.shareAmount, 2500);
      expect(invite.maxUses, 5);
      expect(invite.slotsLeft, 5);
      expect(invite.expiresAt, DateTime.utc(2026, 10, 3, 10));
      expect(
        invite.joinUrl,
        'https://beels-frontend-production.up.railway.app/join/abc123',
      );
      expect(invite.exhausted, isFalse);
    });

    test('previewInvite parses the nested beel and organizer', () async {
      final client = _FakeApiClient()
        ..handlers['/invites/tok42'] = () => {
              'statusCode': 200,
              'message': 'OK',
              'data': {
                'beel': {
                  'name': 'Family Savings',
                  'recurrence_type': 'monthly',
                  'next_occurrence': '2026-09-28T04:15:07.000Z',
                  'amount_per_contributor': 150000,
                },
                'organizer': {'first_name': 'Chuka', 'last_name': 'Obi'},
                'share_amount': 150000,
                'slots_left': 7,
              },
            };
      final repo = BeelsRepository(client);

      final preview = await repo.previewInvite('tok42');

      expect(client.calls.single.path, '/invites/tok42');
      expect(preview.beelName, 'Family Savings');
      expect(preview.recurrenceType, 'monthly');
      expect(preview.amountPerContributor, 1500);
      expect(preview.shareAmount, 1500);
      expect(preview.slotsLeft, 7);
      expect(preview.organizerLabel, 'Chuka O.');
    });

    test('acceptInvite parses the contributor row', () async {
      final client = _FakeApiClient()
        ..handlers['/invites/tok42/accept'] = () => {
              'statusCode': 200,
              'message': 'joined',
              'data': {
                'contributor': {
                  'id': 77,
                  'unit_amount': 150000,
                  'first_name': 'Amaka',
                },
                'beel_name': 'Family Savings',
                'slots_left': 6,
              },
            };
      final repo = BeelsRepository(client);

      final result = await repo.acceptInvite('tok42');

      expect(client.calls.single.path, '/invites/tok42/accept');
      expect(client.calls.single.body, isNull);
      expect(result.contributorId, 77);
      expect(result.unitAmount, 1500);
      expect(result.firstName, 'Amaka');
      expect(result.beelName, 'Family Savings');
      expect(result.slotsLeft, 6);
    });
  });

  group('initiateQuickDebit', () {
    test('posts the activation payload and parses the account envelope',
        () async {
      final client = _FakeApiClient()
        ..handlers['/contributions/contributors/quick-debit/nCFf1kFMUyCWgZ7iIAEz'] =
            () => {
                  'data': {
                    'account_name': 'PWA Live Test',
                    'account_number': '9016323384',
                    'bank_name': 'Polaris Bank Limited',
                    'expiry_date': '2026-09-23 20:26:55',
                  },
                  'message': 'Activation account number fetched',
                  'statusCode': 200,
                };
      final repository = BeelsRepository(client);

      final activation = await repository.initiateQuickDebit(
        identifier: 'nCFf1kFMUyCWgZ7iIAEz',
        bankCode: '076',
        accountNumber: '9016323384',
      );

      expect(client.calls, hasLength(1));
      expect(client.calls.single.path,
          '/contributions/contributors/quick-debit/nCFf1kFMUyCWgZ7iIAEz');
      expect(client.calls.single.body, {
        'identifier': 'nCFf1kFMUyCWgZ7iIAEz',
        'bank_code': '076',
        'account_number': '9016323384',
      });
      expect(activation.accountNumber, '9016323384');
      expect(activation.accountName, 'PWA Live Test');
      expect(activation.bankName, 'Polaris Bank Limited');
      expect(activation.expiryDate, '2026-09-23 20:26:55');
    });

    test('surfaces API errors when activation fails', () async {
      final client = _FakeApiClient();
      final repository = BeelsRepository(client);

      await expectLater(
        repository.initiateQuickDebit(
          identifier: 'missing',
          bankCode: '076',
          accountNumber: '9016323384',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('groupHealth', () {
    test('parses the enveloped health body', () async {
      final client = _FakeApiClient()
        ..handlers['/group-health/29'] = () => {
              'statusCode': 200,
              'message': 'Health report',
              'data': {
                'contribution': {'id': 29, 'name': 'Pay Probe Beel'},
                'report': {
                  'score': 72,
                  'risk_level': 'watch',
                  'shortfall_pct': 25,
                  'late_contributors_count': 2,
                  'suggested_interventions': [
                    {
                      'key': 'nudge_late_contributors',
                      'label': 'Nudge late contributors',
                      'detail': '2 contributors behind.',
                      'auto_executable': true,
                    },
                  ],
                },
              },
            };
      final repository = BeelsRepository(client);

      final health = await repository.groupHealth(29);

      expect(client.calls.single.path, '/group-health/29');
      expect(health!.score, 72);
      expect(health.riskLevel, 'watch');
      expect(health.interventions.single.autoExecutable, isTrue);
    });

    test('parses a bare non-enveloped body', () async {
      final client = _FakeApiClient()
        ..handlers['/group-health/29'] = () => {
              'contribution': {'id': 29},
              'report': {'score': 55, 'risk_level': 'at_risk'},
            };
      final repository = BeelsRepository(client);

      final health = await repository.groupHealth(29);

      expect(health!.score, 55);
      expect(health.riskLevel, 'at_risk');
    });

    test('returns null when no report exists in the body', () async {
      final client = _FakeApiClient()
        ..handlers['/group-health/29'] = () => {
              'contribution': {'id': 29},
            };
      final repository = BeelsRepository(client);

      expect(await repository.groupHealth(29), isNull);
    });
  });

  group('intervene', () {
    test('posts the intervention key and parses the nudge counters',
        () async {
      final client = _FakeApiClient()
        ..handlers['/group-health/29/intervene'] = () => {
              'executed': true,
              'intervention': 'nudge_late_contributors',
              'nudged': 2,
              'total_late': 3,
            };
      final repository = BeelsRepository(client);

      final result = await repository.intervene(
        29,
        interventionKey: 'nudge_late_contributors',
      );

      expect(client.calls.single.path, '/group-health/29/intervene');
      expect(client.calls.single.body,
          {'intervention_key': 'nudge_late_contributors'});
      expect(result.executed, isTrue);
      expect(result.nudged, 2);
      expect(result.totalLate, 3);
    });
  });
}

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
