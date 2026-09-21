import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/contacts/contact_picker.dart';

void main() {
  group('splitName', () {
    test('splits first and last', () {
      expect(splitName('Ada Okafor'), ('Ada', 'Okafor'));
    });

    test('keeps middle names with the last name', () {
      expect(splitName('Ada Ngozi Okafor'), ('Ada', 'Ngozi Okafor'));
    });

    test('single name leaves last name empty', () {
      expect(splitName('Mama Ibeji'), ('Mama', 'Ibeji'));
      expect(splitName('Ada'), ('Ada', ''));
    });

    test('blank input is safe', () {
      expect(splitName('   '), ('', ''));
      expect(splitName(''), ('', ''));
    });
  });

  group('normalizeNigerianPhone', () {
    test('strips spaces, dashes and brackets', () {
      expect(normalizeNigerianPhone('0801 234-5678'), '08012345678');
      expect(normalizeNigerianPhone('(0801) 234 5678'), '08012345678');
    });

    test('converts +234 and 234 forms to local', () {
      expect(normalizeNigerianPhone('+234 801 234 5678'), '08012345678');
      expect(normalizeNigerianPhone('2348012345678'), '08012345678');
    });

    test('leaves other international numbers alone', () {
      expect(normalizeNigerianPhone('+44 7700 900123'), '+447700900123');
    });

    test('short numbers are not mangled', () {
      expect(normalizeNigerianPhone('234'), '234');
    });
  });

  group('PickedContact', () {
    test('fromMap normalises name and phone', () {
      final c = PickedContact.fromMap({
        'name': 'Ada Okafor',
        'phone': '+234 801 234 5678',
        'email': ' ada@beels.test ',
      });
      expect(c.firstName, 'Ada');
      expect(c.lastName, 'Okafor');
      expect(c.phone, '08012345678');
      expect(c.email, 'ada@beels.test');
    });

    test('fromMap tolerates missing values', () {
      final c = PickedContact.fromMap({'name': 'Ada', 'phone': null});
      expect(c.lastName, '');
      expect(c.phone, '');
      expect(c.email, '');
    });

    test('fillInto only overwrites fields the contact has', () {
      final first = TextEditingController(text: 'x');
      final last = TextEditingController(text: 'keep');
      final email = TextEditingController(text: 'keep@me.test');
      final phone = TextEditingController();
      addTearDown(() {
        first.dispose();
        last.dispose();
        email.dispose();
        phone.dispose();
      });

      const PickedContact(firstName: 'Ada', phone: '08012345678').fillInto(
        firstName: first,
        lastName: last,
        email: email,
        phone: phone,
      );

      expect(first.text, 'Ada');
      expect(last.text, 'keep');
      expect(email.text, 'keep@me.test');
      expect(phone.text, '08012345678');
    });
  });
}
