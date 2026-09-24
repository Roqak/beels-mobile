import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/beels/create/beel_draft.dart';

DraftContributor _person(int id,
        {String first = 'Ada',
        String last = 'Obi',
        String email = 'ada@beels.test',
        String phone = '08012345678',
        String amount = '20000'}) =>
    DraftContributor(
        id: id,
        firstName: first,
        lastName: last,
        email: email,
        phone: phone,
        amount: amount);

DraftBeneficiary _bank({
  String name = 'Ada Obi',
  String account = '0123456789',
  String code = '058',
  String amount = '',
}) =>
    DraftBeneficiary(
        id: 1,
        name: name,
        accountNumber: account,
        bankCode: code,
        amount: amount);

void main() {
  group('parseMoney', () {
    test('handles commas, spaces and blanks', () {
      expect(parseMoney('1,250.50'), 1250.5);
      expect(parseMoney(' 40000 '), 40000);
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
    });
  });

  group('validateBasics', () {
    test('needs a name and a positive target', () {
      expect(validateBasics(const BeelDraft()).keys, ['name', 'amount']);
      expect(
        validateBasics(const BeelDraft(name: 'Rent', amount: '0')).keys,
        ['amount'],
      );
      expect(
        validateBasics(const BeelDraft(name: 'Rent', amount: '60,000')),
        isEmpty,
      );
    });
  });

  group('validatePeople (closed)', () {
    test('at least one person', () {
      final e = validatePeople(const BeelDraft(amount: '1000'));
      expect(e['people'], 'Add at least one person');
    });

    test('flags every missing field per person by index', () {
      final d = BeelDraft(
        amount: '1000',
        contributorSplit: ContributorSplit.custom,
        contributors: [
          _person(1),
          const DraftContributor(id: 2),
        ],
      );
      final e = validatePeople(d);
      expect(e.containsKey('contributor_0_first'), isFalse);
      expect(e.keys.where((k) => k.startsWith('contributor_1_')).toSet(), {
        'contributor_1_first',
        'contributor_1_last',
        'contributor_1_email',
        'contributor_1_phone',
        'contributor_1_amount',
      });
    });

    test('phone needs 11 digits after stripping punctuation', () {
      final d = BeelDraft(
        amount: '20000',
        contributors: [_person(1, phone: '0801 234 567')],
      );
      expect(validatePeople(d)['contributor_0_phone'], 'At least 11 digits');
      final ok = d.copyWith(contributors: [_person(1, phone: '0801 234 5678')]);
      expect(validatePeople(ok), isEmpty);
    });

    test('amounts must add up to the target', () {
      final d = BeelDraft(
        amount: '60000',
        contributorSplit: ContributorSplit.custom,
        contributors: [_person(1), _person(2, amount: '30000')],
      );
      expect(validatePeople(d)['people'],
          'Amounts add up to ₦50,000, but the target is ₦60,000');
      expect(
        validatePeople(d.copyWith(amount: '50000')),
        isEmpty,
      );
    });
  });

  group('validatePeople (open)', () {
    test('even split needs a head count', () {
      const d = BeelDraft(mode: BeelMode.open, amount: '9000');
      expect(validatePeople(d).keys, ['expected']);
      expect(
        validatePeople(d.copyWith(expectedContributors: '3')),
        isEmpty,
      );
    });

    test('fixed price needs an amount', () {
      const d = BeelDraft(
          mode: BeelMode.open, amount: '9000', openSplit: OpenSplit.fixed);
      expect(validatePeople(d).keys, ['per_person']);
      expect(validatePeople(d.copyWith(perContributor: '3000')), isEmpty);
    });

    test('per-person preview is live', () {
      const d = BeelDraft(
          mode: BeelMode.open, amount: '9000', expectedContributors: '4');
      expect(d.perPersonPreview, 2250);
      expect(
        d
            .copyWith(openSplit: OpenSplit.fixed, perContributor: '500')
            .perPersonPreview,
        500,
      );
      expect(const BeelDraft(mode: BeelMode.open).perPersonPreview, isNull);
    });
  });

  group('validatePayout', () {
    test('needs at least one beneficiary', () {
      expect(validatePayout(const BeelDraft(amount: '100'))['payout'],
          'Add at least one beneficiary');
    });

    test('a single bank beneficiary defaults to the whole target', () {
      final d = BeelDraft(amount: '60000', beneficiaries: [_bank()]);
      expect(d.effectiveBeneficiaryAmount(d.beneficiaries.first), 60000);
      expect(validatePayout(d), isEmpty);
      expect(d.toBeneficiaryInputs().single.amount, 60000);
    });

    test('bank fields are required, service fields for other types', () {
      const d = BeelDraft(
        amount: '100',
        beneficiaries: [DraftBeneficiary(id: 1)],
      );
      expect(validatePayout(d).keys.toSet(), {
        'beneficiary_0_name',
        'beneficiary_0_bank',
        'beneficiary_0_account'
      });

      const airtime = BeelDraft(
        amount: '100',
        beneficiaries: [DraftBeneficiary(id: 1, type: 'airtime')],
      );
      expect(validatePayout(airtime).keys.toSet(), {
        'beneficiary_0_name',
        'beneficiary_0_service_number',
        'beneficiary_0_service_identifier',
      });
    });

    test('several beneficiaries must be given amounts that add up', () {
      final d = BeelDraft(
        amount: '60000',
        beneficiaries: [
          _bank(amount: '40000'),
          _bank(name: 'Bode', amount: '10000').copyWith(),
        ],
      );
      expect(validatePayout(d)['payout'],
          'Payouts add up to ₦50,000, but the target is ₦60,000');

      final missing = d.copyWith(beneficiaries: [
        _bank(amount: '40000'),
        _bank(name: 'Bode'),
      ]);
      expect(
          validatePayout(missing).containsKey('beneficiary_1_amount'), isTrue);

      final ok = d.copyWith(beneficiaries: [
        _bank(amount: '40000'),
        _bank(name: 'Bode', amount: '20000'),
      ]);
      expect(validatePayout(ok), isEmpty);
    });

    test('service-only payouts carry no amount and skip the sum check', () {
      const d = BeelDraft(
        amount: '5000',
        beneficiaries: [
          DraftBeneficiary(
            id: 1,
            type: 'electricity',
            name: 'IKEDC',
            serviceNumber: '1234567',
            serviceIdentifier: 'ikeja',
          ),
        ],
      );
      expect(validatePayout(d), isEmpty);
      expect(d.toBeneficiaryInputs().single.amount, isNull);
    });
  });

  group('splitEvenly', () {
    test('divides exactly when it can', () {
      expect(splitEvenly(60000, 3), [20000, 20000, 20000]);
    });

    test('remainder kobo go to the first people and always add up', () {
      final parts = splitEvenly(100, 3);
      expect(parts, [33.34, 33.33, 33.33]);
      expect(parts.fold<num>(0, (a, b) => a + b).toStringAsFixed(2), '100.00');
    });

    test('edge cases', () {
      expect(splitEvenly(100, 0), isEmpty);
      expect(splitEvenly(0, 2), [0, 0]);
      expect(splitEvenly(5, 1), [5]);
    });
  });

  group('contributor totals', () {
    test('remaining goes negative when over-assigned', () {
      final d = BeelDraft(
        amount: '30000',
        contributorSplit: ContributorSplit.custom,
        contributors: [_person(1), _person(2, amount: '15000')],
      );
      expect(d.contributorTotal, 35000);
      expect(d.contributorRemaining, -5000);
    });
  });

  group('recurrence', () {
    test('sentences', () {
      expect(recurrenceSentence(const BeelDraft()), 'One time only');
      expect(recurrenceSentence(const BeelDraft(recurrenceType: 'daily')),
          'Every day');
      expect(
          recurrenceSentence(
              const BeelDraft(recurrenceType: 'weekly', dayOfWeek: 'friday')),
          'Every Friday');
      expect(
          recurrenceSentence(
              const BeelDraft(recurrenceType: 'monthly', dayOfMonth: 15)),
          'On day 15 of every month');
    });

    test('next weekly run is the next matching weekday, never today', () {
      // Monday 21 Sep 2026.
      final now = DateTime(2026, 9, 21, 15);
      expect(
        nextRun(const BeelDraft(recurrenceType: 'weekly', dayOfWeek: 'monday'),
            now),
        DateTime(2026, 9, 28),
      );
      expect(
        nextRun(const BeelDraft(recurrenceType: 'weekly', dayOfWeek: 'friday'),
            now),
        DateTime(2026, 9, 25),
      );
    });

    test('next monthly run clamps to short months and rolls over', () {
      expect(
        nextRun(const BeelDraft(recurrenceType: 'monthly', dayOfMonth: 31),
            DateTime(2026, 2, 10)),
        DateTime(2026, 2, 28),
      );
      expect(
        nextRun(const BeelDraft(recurrenceType: 'monthly', dayOfMonth: 5),
            DateTime(2026, 9, 21)),
        DateTime(2026, 10, 5),
      );
      expect(
        nextRun(const BeelDraft(recurrenceType: 'monthly', dayOfMonth: 5),
            DateTime(2026, 12, 21)),
        DateTime(2027, 1, 5),
      );
    });

    test('daily is tomorrow; one-time has no schedule', () {
      final now = DateTime(2026, 9, 21);
      expect(nextRun(const BeelDraft(recurrenceType: 'daily'), now),
          DateTime(2026, 9, 22));
      expect(nextRun(const BeelDraft(), now), isNull);
    });
  });

  group('dirty tracking and inputs', () {
    test('pristine draft is not dirty; typing makes it dirty', () {
      expect(const BeelDraft().isDirty, isFalse);
      expect(const BeelDraft(name: 'x').isDirty, isTrue);
    });

    test('contributor inputs are trimmed and typed', () {
      final d = BeelDraft(
        amount: '20000',
        contributors: [_person(1, first: ' Ada ', amount: '20,000')],
      );
      final input = d.toContributorInputs().single;
      expect(input.firstName, 'Ada');
      expect(input.amount, 20000);
    });
  });

  group('even split (derived amounts)', () {
    test('is the default', () {
      expect(const BeelDraft().contributorSplit, ContributorSplit.even);
      expect(const BeelDraft().sharesEvenly, isTrue);
    });

    test('shares are the target divided between everyone, exactly', () {
      final d = BeelDraft(
        amount: '60000',
        contributors: [
          _person(1, amount: ''),
          _person(2, amount: ''),
          _person(3, amount: '')
        ],
      );
      expect(d.evenShares, [20000, 20000, 20000]);
      expect(d.effectiveContributorAmount(1), 20000);
      expect(d.contributorTotal, 60000);
    });

    test('an uneven division still adds up to the kobo', () {
      final d = BeelDraft(
        amount: '100',
        contributors: [
          _person(1, amount: ''),
          _person(2, amount: ''),
          _person(3, amount: '')
        ],
      );
      expect(d.evenShares, [33.34, 33.33, 33.33]);
      expect(d.contributorTotal.toStringAsFixed(2), '100.00');
    });

    test('shares re-derive as people are added or removed', () {
      final two = BeelDraft(
        amount: '60000',
        contributors: [_person(1, amount: ''), _person(2, amount: '')],
      );
      expect(two.evenShares, [30000, 30000]);
      final three = two.copyWith(
          contributors: [...two.contributors, _person(3, amount: '')]);
      expect(three.evenShares, [20000, 20000, 20000]);
      final one = two.copyWith(contributors: [two.contributors.first]);
      expect(one.evenShares, [60000]);
    });

    test('nothing to derive without a target or people', () {
      expect(const BeelDraft().evenShares, isEmpty);
      expect(
        BeelDraft(contributors: [_person(1, amount: '')]).evenShares,
        isEmpty,
      );
    });

    test('a person needs no typed amount, and totals cannot mismatch', () {
      final d = BeelDraft(
        amount: '60000',
        contributors: [_person(1, amount: ''), _person(2, amount: '')],
      );
      expect(validatePeople(d), isEmpty);
    });

    test('typed amounts are ignored while sharing evenly', () {
      final d = BeelDraft(
        amount: '60000',
        contributors: [_person(1, amount: '1'), _person(2, amount: '2')],
      );
      expect(d.effectiveContributorAmount(0), 30000);
      expect(validatePeople(d), isEmpty);
    });

    test('inputs carry the derived amounts', () {
      final d = BeelDraft(
        amount: '90000',
        contributors: [
          _person(1, amount: ''),
          _person(2, amount: ''),
          _person(3, amount: '')
        ],
      );
      expect(
          d.toContributorInputs().map((c) => c.amount), [30000, 30000, 30000]);
    });

    test('custom mode still requires typed amounts that add up', () {
      final d = BeelDraft(
        amount: '60000',
        contributorSplit: ContributorSplit.custom,
        contributors: [_person(1, amount: ''), _person(2, amount: '')],
      );
      expect(validatePeople(d).keys,
          containsAll(['contributor_0_amount', 'contributor_1_amount']));
    });
  });
  group('kobo-exact validation', () {
    BeelDraft customContributors(List<String> amounts) => BeelDraft(
          mode: BeelMode.closed,
          name: 'Probe',
          amount: '200',
          recurrenceType: 'weekly',
          contributorSplit: ContributorSplit.custom,
          contributors: [
            for (var i = 0; i < 3; i++)
              DraftContributor(id: i, firstName: 'P$i', amount: amounts[i]),
          ],
          beneficiaries: [DraftBeneficiary(id: 0, type: 'airtime', name: 'X')],
          nextId: 4,
        );

    test('accepts custom amounts that sum to the target only in exact kobo',
        () {
      final errors = validatePeople(const BeelDraft(
        mode: BeelMode.closed,
        name: 'Probe',
        amount: '200',
        recurrenceType: 'weekly',
        contributorSplit: ContributorSplit.custom,
        contributors: [
          DraftContributor(id: 1, firstName: 'A', amount: '100.10'),
          DraftContributor(id: 2, firstName: 'B', amount: '50.05'),
          DraftContributor(id: 3, firstName: 'B', amount: '49.85'),
        ],
        beneficiaries: [DraftBeneficiary(id: 0, type: 'airtime', name: 'Air')],
        nextId: 4,
      ));
      expect(errors['people'], isNull);
    });

    test('still rejects amounts that genuinely do not add up', () {
      final errors = validatePeople(const BeelDraft(
        mode: BeelMode.closed,
        name: 'Probe',
        amount: '200',
        recurrenceType: 'weekly',
        contributorSplit: ContributorSplit.custom,
        contributors: [
          DraftContributor(
              id: 1,
              firstName: 'A',
              lastName: 'B',
              email: 'a@x.ng',
              phone: '08012345678',
              amount: '100'),
          DraftContributor(
              id: 2,
              firstName: 'B',
              lastName: 'C',
              email: 'b@x.ng',
              phone: '08012345679',
              amount: '50.01'),
          DraftContributor(
              id: 3,
              firstName: 'C',
              lastName: 'D',
              email: 'c@x.ng',
              phone: '08012345670',
              amount: '50'),
        ],
        beneficiaries: [DraftBeneficiary(id: 0, type: 'airtime', name: 'X')],
        nextId: 4,
      ));
      expect(errors['people'], isNotNull);
    });

    test('payout sums compare in exact kobo', () {
      final errors = validatePayout(const BeelDraft(
        mode: BeelMode.closed,
        name: 'Probe',
        amount: '200',
        recurrenceType: 'weekly',
        contributors: [DraftContributor(id: 1, firstName: 'A')],
        beneficiaries: [
          DraftBeneficiary(id: 0, name: 'A', accountNumber: '1', bankCode: '058'),
          DraftBeneficiary(id: 1, name: 'B', accountNumber: '2', bankCode: '044', amount: '50.05'),
        ],
        nextId: 2,
      ));
      expect(errors['payout'], isNull);
    });
  });

  group('draft persistence roundtrip', () {
    test('toJson/fromJson preserves every field', () {
      const draft = BeelDraft(
        mode: BeelMode.open,
        name: 'Christmas Ajo',
        amount: '5000',
        recurrenceType: 'monthly',
        dayOfWeek: 'friday',
        dayOfMonth: 5,
        contributors: [
          DraftContributor(id: 7, firstName: 'Ada', lastName: 'Okafor',
              email: 'ada@x.ng', phone: '0801', amount: '2500'),
        ],
        beneficiaries: [
          DraftBeneficiary(id: 9, type: 'airtime', name: 'Ada',
              serviceNumber: '0802', amount: '5000'),
        ],
        contributorSplit: ContributorSplit.custom,
        openSplit: OpenSplit.fixed,
        perContributor: '1000',
        expectedContributors: '12',
        nextId: 10,
      );

      final restored = draftFromJson(draftToJson(draft));
      expect(restored.mode, BeelMode.open);
      expect(restored.name, 'Christmas Ajo');
      expect(restored.amount, '5000');
      expect(restored.recurrenceType, 'monthly');
      expect(restored.dayOfMonth, 5);
      expect(restored.contributorSplit, ContributorSplit.custom);
      expect(restored.openSplit, OpenSplit.fixed);
      expect(restored.perContributor, '1000');
      expect(restored.expectedContributors, '12');
      expect(restored.nextId, 10);
      expect(restored.contributors.single.amount, '2500');
      expect(restored.contributors.single.phone, '0801');
      expect(restored.beneficiaries.single.type, 'airtime');
      expect(restored.beneficiaries.single.serviceNumber, '0802');
    });

    test('tolerates a malformed saved payload with defaults', () {
      final restored = draftFromJson('garbage');
      expect(restored.name, '');
      expect(restored.contributors, isEmpty);
      expect(restored.beneficiaries, isEmpty);
    });

    test('isDirty stays false for a pristine restored draft', () {
      expect(draftFromJson(draftToJson(const BeelDraft())).isDirty, isFalse);
    });
  });

}
