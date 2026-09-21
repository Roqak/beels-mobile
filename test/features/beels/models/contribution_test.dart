import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/beels/models/contribution.dart';

void main() {
  group('Contribution.fromJson', () {
    test('parses a closed beel with contributors and beneficiaries', () {
      final beel = Contribution.fromJson({
        'id': 7,
        'name': 'Family Savings',
        'unit_amount': 5000,
        'total_amount': 60000,
        'status': 'active',
        'recurrence_type': 'weekly',
        'day_of_week': 'monday',
        'occurrences': 12,
        'next_occurrence': '2026-09-21T00:00:00.000Z',
        'contribution_mode': 'closed',
        'created_at': '2026-09-01T10:30:00.000Z',
        'contributors': [
          {
            'id': 3,
            'first_name': 'Ada',
            'last_name': 'Obi',
            'email': 'ada@example.com',
            'phone_number': '08012345678',
            'unit_amount': '5000',
            'amount_paid': 10000,
            'status': 'active',
            'bank_name': 'GTBank',
            'payment_id': 'JYLCWKtfdHVzihITWPSq',
          },
        ],
        'beneficiaries': [
          {
            'id': 9,
            'name': 'Mama',
            'type': 'bank_transfer',
            'status': 'settled',
            'amount': 60000,
            'account_number': '0123456789',
            'bank_code': '058',
          },
        ],
      });

      expect(beel.id, 7);
      expect(beel.name, 'Family Savings');
      expect(beel.unitAmount, 5000);
      expect(beel.totalAmount, 60000);
      expect(beel.status, 'active');
      expect(beel.recurrenceType, 'weekly');
      expect(beel.dayOfWeek, 'monday');
      expect(beel.occurrences, 12);
      expect(beel.nextOccurrence, DateTime.utc(2026, 9, 21));
      expect(beel.isOpenLink, isFalse);
      expect(beel.createdAt, DateTime.utc(2026, 9, 1, 10, 30));

      expect(beel.contributors, hasLength(1));
      final contributor = beel.contributors.single;
      expect(contributor.fullName, 'Ada Obi');
      expect(contributor.email, 'ada@example.com');
      expect(contributor.phoneNumber, '08012345678');
      expect(contributor.unitAmount, 5000);
      expect(contributor.amountPaid, 10000);
      expect(contributor.status, 'active');
      expect(contributor.bankName, 'GTBank');

      expect(beel.beneficiaries, hasLength(1));
      final beneficiary = beel.beneficiaries.single;
      expect(beneficiary.name, 'Mama');
      expect(beneficiary.typeLabel, 'Bank transfer');
      expect(beneficiary.status, 'settled');
      expect(beneficiary.amount, 60000);
      expect(beneficiary.accountNumber, '0123456789');
      expect(beneficiary.bankCode, '058');
    });

    test('parses an open-link beel', () {
      final beel = Contribution.fromJson({
        'id': 12,
        'name': 'Birthday Fund',
        'contribution_mode': 'open_link',
        'status': 'pending',
        'payment_link_token': 'tok_abc',
        'amount_per_contributor': '2500.5',
        'total_amount': 25000,
      });

      expect(beel.isOpenLink, isTrue);
      expect(beel.paymentLinkToken, 'tok_abc');
      expect(beel.amountPerContributor, 2500.5);
      expect(beel.contributors, isEmpty);
      expect(beel.beneficiaries, isEmpty);
    });

    test('treats list rows without nested collections as empty', () {
      final beel = Contribution.fromJson({
        'id': 5,
        'name': 'List Row',
        'status': 'active',
      });

      expect(beel.contributors, isEmpty);
      expect(beel.beneficiaries, isEmpty);
      expect(beel.unitAmount, isNull);
      expect(beel.nextOccurrence, isNull);
    });

    test('defaults everything on an empty map', () {
      final beel = Contribution.fromJson(const {});

      expect(beel.id, isNull);
      expect(beel.name, '');
      expect(beel.status, '');
      expect(beel.contributionMode, 'closed');
      expect(beel.isOpenLink, isFalse);
      expect(beel.contributors, isEmpty);
      expect(beel.beneficiaries, isEmpty);
    });

    test('accepts numeric values as strings', () {
      final beel = Contribution.fromJson({
        'name': 'String numbers',
        'unit_amount': '5000.5',
        'occurrences': '12',
        'day_of_month': '15',
        'total_amount': '60000',
      });

      expect(beel.unitAmount, 5000.5);
      expect(beel.occurrences, 12);
      expect(beel.dayOfMonth, 15);
      expect(beel.totalAmount, 60000);
    });
  });

  group('Participation.fromJson', () {
    test('maps the my-participation row shape', () {
      final participation = Participation.fromJson({
        'contributor_id': 42,
        'status': 'active',
        'expected_amount': 5000,
        'amount_paid': '15000',
        'next_occurrence': '2026-10-01T00:00:00.000Z',
        'contribution': {
          'id': 7,
          'name': 'Office Ajo',
          'next_occurrence': '2026-10-02T00:00:00.000Z',
        },
        'payments': [
          {'id': 1, 'amount': 5000},
        ],
      });

      expect(participation.id, 42);
      expect(participation.name, 'Office Ajo');
      expect(participation.unitAmount, 5000);
      expect(participation.amountPaid, 15000);
      expect(participation.status, 'active');
      expect(participation.nextOccurrence, DateTime.utc(2026, 10, 1));
    });

    test('falls back to the nested contribution for identity and date', () {
      final participation = Participation.fromJson({
        'contribution': {
          'id': 7,
          'name': 'Office Ajo',
          'next_occurrence': '2026-10-02T00:00:00.000Z',
        },
      });

      expect(participation.id, 7);
      expect(participation.name, 'Office Ajo');
      expect(participation.nextOccurrence, DateTime.utc(2026, 10, 2));
      expect(participation.unitAmount, isNull);
      expect(participation.amountPaid, isNull);
    });
  });

  group('recurrenceLabel', () {
    Contribution beel(Map<String, dynamic> json) => Contribution.fromJson(json);

    test('weekly with a day', () {
      expect(
        recurrenceLabel(beel({
          'name': 'B',
          'recurrence_type': 'weekly',
          'day_of_week': 'monday',
        })),
        'Weekly · Monday',
      );
    });

    test('weekly without a day', () {
      expect(
        recurrenceLabel(beel({'name': 'B', 'recurrence_type': 'weekly'})),
        'Weekly',
      );
    });

    test('monthly with a day', () {
      expect(
        recurrenceLabel(beel({
          'name': 'B',
          'recurrence_type': 'monthly',
          'day_of_month': 15,
        })),
        'Monthly · Day 15',
      );
    });

    test('daily and one-time', () {
      expect(
        recurrenceLabel(beel({'name': 'B', 'recurrence_type': 'daily'})),
        'Daily',
      );
      expect(
        recurrenceLabel(beel({'name': 'B', 'recurrence_type': 'one_time'})),
        'One-time',
      );
    });

    test('unknown recurrence falls back to the raw value', () {
      expect(
        recurrenceLabel(beel({'name': 'B', 'recurrence_type': 'quarterly'})),
        'quarterly',
      );
    });
  });

  group('BeneficiaryInput.toJson', () {
    test('omits null keys and keeps amounts for bank transfer', () {
      final json = BeneficiaryInput(
        name: 'Mama',
        type: 'bank_transfer',
        accountNumber: '0123456789',
        bankCode: '058',
        amount: 60000,
      ).toJson();

      expect(json, {
        'name': 'Mama',
        'type': 'bank_transfer',
        'account_number': '0123456789',
        'bank_code': '058',
        'amount': 60000,
      });
    });

    test('service rows omit bank fields and null amounts', () {
      final json = BeneficiaryInput(
        name: 'Line',
        type: 'data',
        serviceNumber: '08012345678',
        serviceIdentifier: 'MTN',
      ).toJson();

      expect(json, {
        'name': 'Line',
        'type': 'data',
        'service_number': '08012345678',
        'service_identifier': 'MTN',
      });
    });
  });

  group('ContributorInput.toJson', () {
    test('emits the snake_case payload shape', () {
      final json = ContributorInput(
        firstName: 'Ada',
        lastName: 'Obi',
        email: 'ada@example.com',
        phoneNumber: '08012345678',
        amount: 5000,
      ).toJson();

      expect(json, {
        'first_name': 'Ada',
        'last_name': 'Obi',
        'email': 'ada@example.com',
        'phone_number': '08012345678',
        'amount': 5000,
      });
    });
  });

  group('ContributionContributor.canPay', () {
    ContributionContributor fromJson(Map<String, Object?> json) =>
        Contribution.fromJson({
          'contributors': [json],
        }).contributors.single;

    test('is payable with a payment id and a non-terminal status', () {
      final contributor = fromJson({
        'id': 3,
        'status': 'active',
        'payment_id': 'JYLCWKtfdHVzihITWPSq',
      });
      expect(contributor.paymentId, 'JYLCWKtfdHVzihITWPSq');
      expect(contributor.canPay, isTrue);
    });

    test('is not payable without a payment id', () {
      final contributor = fromJson({'id': 3, 'status': 'pending'});
      expect(contributor.canPay, isFalse);
    });

    test('is not payable in a terminal status', () {
      final contributor = fromJson({
        'id': 3,
        'status': 'settled',
        'payment_id': 'JYLCWKtfdHVzihITWPSq',
      });
      expect(contributor.canPay, isFalse);
    });
  });
}
