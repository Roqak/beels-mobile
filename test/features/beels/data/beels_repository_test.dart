import 'package:flutter_test/flutter_test.dart';

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
}
