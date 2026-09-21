import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/money_input.dart';

String _type(String text) => const ThousandsFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
    .text;

void main() {
  test('adds thousands separators as digits are typed', () {
    expect(_type('6'), '6');
    expect(_type('60'), '60');
    expect(_type('600'), '600');
    expect(_type('6000'), '6,000');
    expect(_type('60000'), '60,000');
    expect(_type('1234567'), '1,234,567');
  });

  test('re-formats text that already has commas', () {
    expect(_type('60,0000'), '600,000');
  });

  test('keeps one decimal point and at most two decimals', () {
    expect(_type('1250.5'), '1,250.5');
    expect(_type('1250.567'), '1,250.56');
    expect(_type('1.2.3'), '1.23');
    expect(_type('.5'), '0.5');
  });

  test('drops non-numeric characters and empty input', () {
    expect(_type('₦1a2b'), '12');
    expect(_type(''), '');
    expect(_type('abc'), '');
  });

  test('leading zeros are removed but a lone zero stays', () {
    expect(_type('007'), '7');
    expect(_type('0'), '0');
    expect(_type('000'), '0');
  });

  test('the cursor stays at the end', () {
    final v = const ThousandsFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '60000'),
    );
    expect(v.selection.baseOffset, v.text.length);
  });
}
