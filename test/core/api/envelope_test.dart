import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/envelope.dart';

void main() {
  group('envelope', () {
    test('unwraps data and passes it to fromData', () {
      final out = envelope<Map>(
        {'statusCode': 200, 'message': 'ok', 'data': {'id': 5, 'name': 'X'}},
        (data) => data as Map,
      );
      expect(out['id'], 5);
    });

    test('passes null data through for non-map bodies', () {
      final out = envelope<String?>('oops', (data) => data as String?);
      expect(out, isNull);
    });
  });

  group('envelopeList', () {
    test('maps a flat list payload', () {
      final out = envelopeList<int>(
        {'data': [{'id': 1}, {'id': 2}]},
        (json) => json['id'] as int,
      );
      expect(out, [1, 2]);
    });

    test('unwraps double-nested data.data', () {
      final out = envelopeList<int>(
        {
          'statusCode': 200,
          'data': {
            'data': [
              {'id': 1},
              {'id': 2},
              {'id': 3},
            ],
          },
        },
        (json) => json['id'] as int,
      );
      expect(out, [1, 2, 3]);
    });

    test('maps a bare list body', () {
      final out = envelopeList<int>([{'id': 9}], (json) => json['id'] as int);
      expect(out, [9]);
    });

    test('returns an empty list when data is not a list', () {
      final out = envelopeList<int>(
        {'data': {'message': 'no list here'}},
        (json) => json['id'] as int,
      );
      expect(out, isEmpty);
    });
  });
}