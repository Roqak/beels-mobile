import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/transactions/models/transaction.dart';

void main() {
  group('Transaction.fromJson', () {
    test('parses a deposit row with nested contributor + contribution', () {
      final transaction = Transaction.fromJson({
        'id': 11,
        'type': 'deposit',
        'amount': 5000,
        'status': 'successful',
        'created_at': '2026-09-10T08:45:00.000Z',
        'deposit': {
          'transaction_reference': 'DEP-0011',
          'amount': 5000,
          'contributor': {
            'id': 3,
            'unit_amount': 5000,
            'contribution': {
              'id': 7,
              'name': 'Family Savings',
              'total_amount': 60000,
              'unit_amount': 5000,
            },
          },
        },
      });

      expect(transaction.id, 11);
      expect(transaction.isDeposit, isTrue);
      expect(transaction.amount, 5000);
      expect(transaction.status, 'successful');
      expect(transaction.createdAt, DateTime.utc(2026, 9, 10, 8, 45));
      expect(transaction.reference, 'DEP-0011');
      expect(transaction.beelName, 'Family Savings');
      expect(transaction.unitAmount, 5000);
      expect(transaction.totalAmount, 60000);
    });

    test('parses a withdrawal row with nested contribution', () {
      final transaction = Transaction.fromJson({
        'type': 'withdrawal',
        'amount': '12000.75',
        'status': 'pending',
        'withdrawal': {
          'transaction_reference': 'WDR-0002',
          'contribution': {
            'name': 'Birthday Fund',
            'unit_amount': '12000.75',
            'total_amount': 24000,
          },
        },
      });

      expect(transaction.isDeposit, isFalse);
      expect(transaction.amount, 12000.75);
      expect(transaction.reference, 'WDR-0002');
      expect(transaction.beelName, 'Birthday Fund');
      expect(transaction.unitAmount, 12000.75);
      expect(transaction.totalAmount, 24000);
    });

    test('defaults on an empty map', () {
      final transaction = Transaction.fromJson(const {});

      expect(transaction.type, '');
      expect(transaction.isDeposit, isFalse);
      expect(transaction.amount, isNull);
      expect(transaction.status, '');
      expect(transaction.reference, isNull);
      expect(transaction.beelName, isNull);
      expect(transaction.unitAmount, isNull);
      expect(transaction.totalAmount, isNull);
    });

    test('falls back to top-level amount when payment payload lacks it', () {
      final transaction = Transaction.fromJson({
        'type': 'deposit',
        'amount': 2500,
        'deposit': {'transaction_reference': 'DEP-0009'},
      });

      expect(transaction.amount, 2500);
      expect(transaction.reference, 'DEP-0009');
      expect(transaction.beelName, isNull);
    });
  });
}
