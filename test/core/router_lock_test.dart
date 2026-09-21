import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/router.dart';

void main() {
  group('lockLocationFor', () {
    test('home needs no return path', () {
      expect(lockLocationFor('/'), '/lock');
    });

    test('other locations round-trip through the from parameter', () {
      const here = '/beels/5?tab=contributors';
      final lock = lockLocationFor(here);

      expect(lock.startsWith('/lock?from='), isTrue);
      expect(Uri.parse(lock).queryParameters['from'], here);
    });
  });

  group('resumeLocationFrom', () {
    test('resumes an in-app location', () {
      expect(resumeLocationFrom('/transactions'), '/transactions');
    });

    test('falls back to home when missing', () {
      expect(resumeLocationFrom(null), '/');
    });

    test('rejects off-app and lock targets', () {
      expect(resumeLocationFrom('https://evil.example'), '/');
      expect(resumeLocationFrom('//evil.example'), '/');
      expect(resumeLocationFrom('/lock'), '/');
      expect(resumeLocationFrom('/lock?from=%2F'), '/');
    });
  });
}
