import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/config.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

void main() {
  group('Group.fromJson', () {
    test('parses a full happy-path payload', () {
      final group = Group.fromJson({
        'id': 3,
        'name': 'Family Savings',
        'description': 'Monthly ajo for the family',
        'invite_link_token': 'tok123abc',
        'invite_link': 'https://beels.app/groups/join/tok123abc',
        'members_count': 2,
        'members': [
          {
            'id': 10,
            'first_name': 'Ada',
            'last_name': 'Obi',
            'email': 'ada@example.com',
            'phone_number': '08012345678',
          },
          {
            'id': 11,
            'first_name': 'Tunde',
            'last_name': 'Bakare',
            'email': 'tunde@example.com',
          },
        ],
        'created_at': '2026-03-01T10:30:00.000Z',
      });

      expect(group.id, 3);
      expect(group.name, 'Family Savings');
      expect(group.description, 'Monthly ajo for the family');
      expect(group.inviteToken, 'tok123abc');
      expect(group.inviteLink, 'https://beels.app/groups/join/tok123abc');
      expect(group.membersCount, 2);
      expect(group.members, hasLength(2));
      expect(group.members[0].fullName, 'Ada Obi');
      expect(group.members[0].phoneNumber, '08012345678');
      expect(group.members[1].phoneNumber, isNull);
      expect(group.createdAt, DateTime.utc(2026, 3, 1, 10, 30));
    });

    test('builds invite link from token when invite_link is absent', () {
      final group = Group.fromJson({
        'id': 1,
        'name': 'Ajọ club',
        'invite_link_token': 'freshToken9',
        'members_count': 0,
        'members': <dynamic>[],
      });

      expect(
        group.inviteLink,
        '${AppConfig.frontendBaseUrl}/groups/join/freshToken9',
      );
    });

    test('accepts the invite_token key variant', () {
      final group = Group.fromJson({
        'id': 1,
        'name': 'Ajọ club',
        'invite_token': 'variantToken',
      });

      expect(group.inviteToken, 'variantToken');
      expect(
        group.inviteLink,
        '${AppConfig.frontendBaseUrl}/groups/join/variantToken',
      );
    });

    test('derives members_count from members when key is absent', () {
      final group = Group.fromJson({
        'id': 5,
        'name': 'No count group',
        'members': [
          {'id': 1, 'first_name': 'Ada'},
          {'id': 2, 'first_name': 'Tunde'},
          {'id': 3, 'first_name': 'Ngozi'},
        ],
      });

      expect(group.membersCount, 3);
    });

    test('stays null-safe when the group has no invite token', () {
      // Backend mapGroup sends invite_link: null while no token exists.
      final group = Group.fromJson({
        'id': 9,
        'name': 'Tokenless',
        'invite_link_token': null,
        'invite_link': null,
        'members': <dynamic>[],
      });

      expect(group.inviteToken, isNull);
      expect(group.inviteLink, isNull);
    });

    test('tolerates empty json and coerces numeric strings', () {
      final group = Group.fromJson({
        'id': '42',
        'name': 'Coerced',
        'members_count': '3',
        'members': <dynamic>[],
      });

      expect(group.id, 42);
      expect(group.membersCount, 3);
      expect(group.description, isNull);
    });

    test('tolerates a completely empty payload', () {
      final group = Group.fromJson({});

      expect(group.id, 0);
      expect(group.name, '');
      expect(group.inviteToken, isNull);
      expect(group.inviteLink, isNull);
      expect(group.membersCount, 0);
      expect(group.members, isEmpty);
      expect(group.createdAt, isNull);
    });
  });

  group('GroupMember.fromJson', () {
    test('parses snake_case payload', () {
      final member = GroupMember.fromJson({
        'id': 4,
        'first_name': 'Ada',
        'last_name': 'Obi',
        'email': 'ada@example.com',
        'phone_number': '08012345678',
      });

      expect(member.id, 4);
      expect(member.firstName, 'Ada');
      expect(member.lastName, 'Obi');
      expect(member.email, 'ada@example.com');
      expect(member.phoneNumber, '08012345678');
      expect(member.fullName, 'Ada Obi');
    });

    test('accepts camelCase and tolerates missing id', () {
      final member = GroupMember.fromJson({
        'firstName': 'Ada',
        'lastName': 'Obi',
        'email': 'ada@example.com',
      });

      expect(member.id, isNull);
      expect(member.firstName, 'Ada');
      expect(member.lastName, 'Obi');
    });

    test('toCreateJson omits empty optional fields', () {
      const member = GroupMember(
        id: 4,
        firstName: 'Ada',
        lastName: '',
        email: 'ada@example.com',
        phoneNumber: null,
      );

      expect(member.toCreateJson(), {
        'first_name': 'Ada',
        'email': 'ada@example.com',
      });
    });

    test('includes phone number when present', () {
      const member = GroupMember(
        firstName: 'Ada',
        lastName: 'Obi',
        email: 'ada@example.com',
        phoneNumber: '08012345678',
      );

      expect(member.toCreateJson(), {
        'first_name': 'Ada',
        'last_name': 'Obi',
        'email': 'ada@example.com',
        'phone_number': '08012345678',
      });
    });
  });
}