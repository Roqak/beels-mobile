import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/money.dart';

void main() {
  group('formatNaira', () {
    test('formats whole numbers without decimals', () {
      expect(formatNaira(1250), '₦1,250');
    });

    test('keeps two decimals for fractional amounts', () {
      expect(formatNaira(1250.5), '₦1,250.50');
    });

    test('treats whole doubles as whole numbers', () {
      expect(formatNaira(1250.0), '₦1,250');
    });

    test('formats zero', () {
      expect(formatNaira(0), '₦0');
    });
  });

  group('formatNairaSigned', () {
    test('prefixes incoming amounts with +', () {
      expect(formatNairaSigned(1250, incoming: true), '+₦1,250');
    });

    test('prefixes outgoing amounts with the minus sign', () {
      expect(formatNairaSigned(1250, incoming: false), '−₦1,250');
    });

    test('uses the flag for sign, magnitude for the number', () {
      expect(formatNairaSigned(-1250.5, incoming: true), '+₦1,250.50');
      expect(formatNairaSigned(-1250.5, incoming: false), '−₦1,250.50');
    });
  });
}
