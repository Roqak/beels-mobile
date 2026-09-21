import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/transactions/data/transactions_repository.dart';

void main() {
  group('TransactionsRepository.parseListResponse', () {
    test('parses the paginated transactions envelope', () {
      final page = TransactionsRepository.parseListResponse({
        'statusCode': 200,
        'message': 'OK',
        'data': [
          {
            'id': 1,
            'type': 'deposit',
            'amount': 5000,
            'status': 'successful',
            'created_at': '2026-09-10T08:00:00.000Z',
            'deposit': {
              'transaction_reference': 'DEP-0001',
              'contributor': {
                'unit_amount': 5000,
                'contribution': {
                  'name': 'Family Savings',
                  'total_amount': 60000
                },
              },
            },
          },
          {
            'id': 2,
            'type': 'withdrawal',
            'amount': 3000,
            'status': 'pending',
            'withdrawal': {
              'transaction_reference': 'WDR-0001',
              'contribution': {'name': 'Birthday Fund'},
            },
          },
        ],
        'current_page': 2,
        'per_page': 20,
        'total': 57,
        'last_page': 3,
      });

      expect(page.items, hasLength(2));
      expect(page.page, 2);
      expect(page.perPage, 20);
      expect(page.total, 57);
      expect(page.lastPage, 3);
      expect(page.items.first.reference, 'DEP-0001');
      expect(page.items.first.beelName, 'Family Savings');
      expect(page.items.last.type, 'withdrawal');
    });

    test('tolerates a malformed envelope', () {
      final page = TransactionsRepository.parseListResponse(const {});

      expect(page.items, isEmpty);
      expect(page.page, 0);
      expect(page.total, 0);
    });
  });
}
