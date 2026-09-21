import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/auth/models/profile.dart';

void main() {
  group('Profile.fromJson', () {
    test('parses a full snake_case payload', () {
      final profile = Profile.fromJson(const {
        'email': 'ada@beels.ng',
        'first_name': 'Ada',
        'last_name': 'Obi',
        'phone_number': '+2348012345678',
        'status': 'ACTIVE',
        'role': 'organizer',
        'id': 12,
        'created_at': '2024-01-01T00:00:00.000Z',
      });

      expect(profile.email, 'ada@beels.ng');
      expect(profile.firstName, 'Ada');
      expect(profile.lastName, 'Obi');
      expect(profile.phoneNumber, '+2348012345678');
      expect(profile.status, 'ACTIVE');
      expect(profile.role, 'organizer');
      expect(profile.fullName, 'Ada Obi');
      expect(profile.initials, 'AO');
    });

    test('falls back to empty strings for missing required fields', () {
      final profile = Profile.fromJson(const <String, dynamic>{});

      expect(profile.email, '');
      expect(profile.firstName, '');
      expect(profile.lastName, isNull);
      expect(profile.phoneNumber, isNull);
      expect(profile.status, isNull);
      expect(profile.role, isNull);
      expect(profile.initials, '?');
    });

    test('accepts camelCase keys and ignores non-map input', () {
      final profile = Profile.fromJson(const {
        'email': 'ada@beels.ng',
        'firstName': 'Ada',
        'phoneNumber': '08012345678',
      });

      expect(profile.email, 'ada@beels.ng');
      expect(profile.firstName, 'Ada');
      expect(profile.phoneNumber, '08012345678');
      expect(Profile.fromJson(null).email, '');
    });

    test('value equality and copyWith', () {
      const a = Profile(email: 'a@b.com', firstName: 'A');
      final b = Profile.fromJson(const {'email': 'a@b.com', 'first_name': 'A'});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      expect(a.copyWith(lastName: 'Obi').lastName, 'Obi');
      expect(a.copyWith(lastName: 'Obi').firstName, 'A');
    });
  });
}