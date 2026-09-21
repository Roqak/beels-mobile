import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';

void main() {
  group('ApiException.fromResponse', () {
    test('uses a string message', () {
      final e = ApiException.fromResponse(
        {'statusCode': 400, 'message': 'Amount is required'},
        400,
      );
      expect(e.message, 'Amount is required');
      expect(e.statusCode, 400);
    });

    test('joins a list of validation messages', () {
      final e = ApiException.fromResponse(
        {
          'statusCode': 422,
          'message': ['Name is required', 'Amount must be positive'],
        },
        422,
      );
      expect(e.message, 'Name is required; Amount must be positive');
      expect(e.statusCode, 422);
    });

    test('falls back to the error field', () {
      final e = ApiException.fromResponse({'error': 'Unauthorized'}, 401);
      expect(e.message, 'Unauthorized');
      expect(e.statusCode, 401);
    });

    test('falls back to a generic message for non-map bodies', () {
      final e = ApiException.fromResponse('oops', 500);
      expect(e.message, 'Something went wrong. Please try again.');
      expect(e.statusCode, 500);
    });
  });

  test('toString includes status and message', () {
    expect(
      const ApiException('bad', statusCode: 404).toString(),
      'ApiException(404): bad',
    );
  });
}
