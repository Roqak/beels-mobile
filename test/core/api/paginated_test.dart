import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/paginated.dart';

class _Item {
  const _Item(this.id);
  final int id;
}

void main() {
  group('Paginated.parse', () {
    test('parses a full Laravel envelope', () {
      final result = Paginated.parse<_Item>(
        {
          'current_page': 1,
          'per_page': 20,
          'total': 57,
          'last_page': 3,
          'data': [
            {'id': 1},
            {'id': 2},
          ],
        },
        (json) => _Item(json['id'] as int),
      );

      expect(result.items.map((i) => i.id), [1, 2]);
      expect(result.page, 1);
      expect(result.perPage, 20);
      expect(result.total, 57);
      expect(result.lastPage, 3);
      expect(result.hasMore, isTrue);
    });

    test('hasMore is false on the last page', () {
      final result = Paginated.parse<_Item>(
        {'current_page': 3, 'last_page': 3, 'data': [{'id': 9}]},
        (json) => _Item(json['id'] as int),
      );
      expect(result.hasMore, isFalse);
    });

    test('tolerates string and double numbers', () {
      final result = Paginated.parse<_Item>(
        {
          'current_page': '2',
          'per_page': 10.0,
          'total': '21',
          'last_page': 2.0,
          'data': [],
        },
        (json) => const _Item(0),
      );

      expect(result.page, 2);
      expect(result.perPage, 10);
      expect(result.total, 21);
      expect(result.lastPage, 2);
    });

    test('falls back to zero when keys are missing', () {
      final result = Paginated.parse<_Item>(
        {'data': null},
        (json) => const _Item(0),
      );

      expect(result.items, isEmpty);
      expect(result.page, 0);
      expect(result.perPage, 0);
      expect(result.total, 0);
      expect(result.lastPage, 0);
      expect(result.hasMore, isFalse);
    });

    test('unwraps double-nested data.data', () {
      final result = Paginated.parse<_Item>(
        {
          'current_page': 1,
          'last_page': 1,
          'data': {
            'data': [{'id': 7}],
          },
        },
        (json) => _Item(json['id'] as int),
      );

      expect(result.items.map((i) => i.id), [7]);
    });
  });
}