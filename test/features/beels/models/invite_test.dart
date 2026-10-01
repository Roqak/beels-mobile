import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/beels/models/invite.dart';

void main() {
  group('BeelInvite.fromJson', () {
    test('converts share_amount from kobo to naira', () {
      final invite = BeelInvite.fromJson({
        'token': 'abc123',
        'join_url': 'https://beels-frontend-production.up.railway.app/join/abc123',
        'share_amount': 250000,
        'max_uses': 5,
        'expires_at': '2026-10-03T10:00:00.000Z',
        'slots_left': 5,
      });

      expect(invite.shareAmount, 2500);
      expect(invite.exhausted, isFalse);
      expect(invite.isExpired, isFalse);
    });

    test('rebuilds the join link when the backend omits it', () {
      final invite = BeelInvite.fromJson({'token': 'tok77'});

      expect(
        invite.joinUrl,
        'https://beels-frontend-production.up.railway.app/join/tok77',
      );
    });

    test('tolerates unknown and malformed fields', () {
      final invite = BeelInvite.fromJson({
        'token': 42, // numbers are tolerated for string fields
        'join_url': null,
        'share_amount': '12.5', // string numbers accepted
        'slots_left': 'n/a',
        'future_field': true,
      });

      expect(invite.token, '42');
      expect(invite.shareAmount, 0.125);
      expect(invite.slotsLeft, isNull);
    });
  });

  group('InvitePreview.fromJson', () {
    test('parses nested beel and organizer, converting kobo', () {
      final preview = InvitePreview.fromJson({
        'beel': {
          'name': 'Family Savings',
          'recurrence_type': 'monthly',
          'next_occurrence': '2026-09-28T04:15:07.000Z',
          'amount_per_contributor': 150000,
        },
        'organizer': {'first_name': 'Chuka', 'last_name': 'Obi'},
        'share_amount': 150000,
        'slots_left': 7,
      });

      expect(preview.beelName, 'Family Savings');
      expect(preview.recurrenceType, 'monthly');
      expect(preview.nextOccurrence, DateTime.utc(2026, 9, 28, 4, 15, 7));
      expect(preview.amountPerContributor, 1500);
      expect(preview.shareAmount, 1500);
      expect(preview.organizerLabel, 'Chuka O.');
    });

    test('degrades to "the organizer" on empty names', () {
      final preview = InvitePreview.fromJson(const {});

      expect(preview.organizerLabel, 'the organizer');
      expect(preview.beelName, '');
    });
  });

  group('joinTokenFromUri', () {
    test('extracts the token from a frontend join link', () {
      final token = joinTokenFromUri(
        Uri.parse(
          'https://beels-frontend-production.up.railway.app/join/tok42',
        ),
      );

      expect(token, 'tok42');
    });

    test('rejects other hosts and other paths', () {
      expect(
        joinTokenFromUri(Uri.parse('https://evil.example.com/join/tok42')),
        isNull,
      );
      expect(
        joinTokenFromUri(
          Uri.parse('https://beels-frontend-production.up.railway.app/pay/join/x'),
        ),
        isNull,
      );
      expect(
        joinTokenFromUri(Uri.parse('https://beels-frontend-production.up.railway.app/join')),
        isNull,
      );
    });
  });
}