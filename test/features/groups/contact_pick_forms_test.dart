import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/contacts/contact_picker.dart';
import 'package:beels_mobile/features/beels/screens/create_beel_screen.dart';
import 'package:beels_mobile/features/groups/screens/create_group_screen.dart';

class _FakePicker implements ContactPicker {
  _FakePicker({this.contact, this.error});

  final PickedContact? contact;
  final ContactPickerException? error;
  int calls = 0;

  @override
  Future<PickedContact?> pick() async {
    calls++;
    if (error != null) throw error!;
    return contact;
  }
}

const _ada = PickedContact(
  firstName: 'Ada',
  lastName: 'Okafor',
  phone: '08012345678',
  email: 'ada@beels.test',
);

Future<void> _pump(WidgetTester tester, Widget screen, ContactPicker picker) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [contactPickerProvider.overrideWithValue(picker)],
      child: MaterialApp(home: screen),
    ),
  );
}

String _text(WidgetTester tester, String hint) {
  final field = find.widgetWithText(TextField, hint);
  return tester.widget<TextField>(field).controller!.text;
}

void main() {
  testWidgets('create beel: picking a contact fills the contributor row',
      (tester) async {
    final picker = _FakePicker(contact: _ada);
    await _pump(tester, const CreateBeelScreen(), picker);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('From contacts'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('From contacts'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(_text(tester, 'First name'), 'Ada');
    expect(_text(tester, 'Last name'), 'Okafor');
    expect(_text(tester, 'Email'), 'ada@beels.test');
    expect(_text(tester, 'Phone number'), '08012345678');
  });

  testWidgets('create group: picking a contact fills the member row',
      (tester) async {
    final picker = _FakePicker(contact: _ada);
    await _pump(tester, const CreateGroupScreen(), picker);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From contacts'));
    await tester.pumpAndSettle();

    expect(_text(tester, 'First name'), 'Ada');
    expect(_text(tester, 'Last name'), 'Okafor');
    expect(_text(tester, 'Email (optional)'), 'ada@beels.test');
    expect(_text(tester, 'Phone (optional)'), '08012345678');
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final picker = _FakePicker(contact: null);
    await _pump(tester, const CreateGroupScreen(), picker);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Bo');
    await tester.tap(find.text('From contacts'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(_text(tester, 'First name'), 'Bo');
  });

  testWidgets('a picker failure shows a message and keeps the form',
      (tester) async {
    final picker = _FakePicker(
      error: const ContactPickerException('No contacts app is available.'),
    );
    await _pump(tester, const CreateGroupScreen(), picker);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From contacts'));
    await tester.pumpAndSettle();

    expect(find.text('No contacts app is available.'), findsOneWidget);
  });
}
