import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/features/dashboard/data/dashboard_repository.dart';

class _RecordedCall {
  _RecordedCall(this.method, this.path, {this.query, this.body});

  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;

  @override
  String toString() => '$method $path';
}

class _RecordingApiClient implements ApiClient {
  _RecordingApiClient();

  final List<_RecordedCall> calls = [];
  final Map<String, dynamic Function()> responses = {};

  dynamic _responseFor(String method, String path) {
    final producer = responses['$method $path'];
    if (producer == null) {
      throw StateError('Unexpected request: $method $path');
    }
    return producer();
  }

  void _record(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) {
    calls.add(_RecordedCall(method, path, query: query, body: body));
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    _record('GET', path, query: query);
    return _responseFor('GET', path);
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    _record('POST', path, body: body);
    return _responseFor('POST', path);
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    _record('PATCH', path, body: body);
    return _responseFor('PATCH', path);
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    _record('PUT', path, body: body);
    return _responseFor('PUT', path);
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) async {
    _record('DELETE', path, body: body);
    return _responseFor('DELETE', path);
  }
}

void main() {
  late _RecordingApiClient api;
  late DashboardRepository repository;

  setUp(() {
    api = _RecordingApiClient();
    repository = DashboardRepository(api);
  });

  group('analytics', () {
    test('GETs /analytics and parses the envelope data', () async {
      api.responses['GET /analytics'] = () => {
            'statusCode': 200,
            'message': 'Analytics Fetched',
            'data': {
              'total_deposited': 150000,
              'total_withdrawn': 40000.5,
              'total_contributions': 12,
              'total_transactions': 57,
            },
          };

      final analytics = await repository.analytics();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.path, '/analytics');
      expect(analytics.totalDeposited, 150000);
      expect(analytics.totalWithdrawn, 40000.5);
      expect(analytics.totalContributions, 12);
      expect(analytics.totalTransactions, 57);
    });

    test('coerces string numbers and tolerates missing keys', () async {
      api.responses['GET /analytics'] = () => {
            'statusCode': 200,
            'message': 'Analytics Fetched',
            'data': {
              'total_deposited': '25000',
              'total_withdrawn': null,
            },
          };

      final analytics = await repository.analytics();

      expect(analytics.totalDeposited, 25000);
      expect(analytics.totalWithdrawn, 0);
      expect(analytics.totalContributions, 0);
      expect(analytics.totalTransactions, 0);
    });
  });

  group('recentTransactions', () {
    test(
        'GETs /transactions with per_page=5 and parses the paginated envelope',
        () async {
      api.responses['GET /transactions'] = () => {
            'statusCode': 200,
            'message': 'Transactions Fetched',
            'data': [
              {
                'id': 1,
                'type': 'deposit',
                'amount': 5000,
                'status': 'completed',
                'created_at': '2026-05-04T09:15:00.000Z',
                'deposit': {
                  'transaction_reference': 'dep-ref-1',
                  'contributor': {
                    'contribution': {'name': 'Weekly Ajo'},
                  },
                },
              },
              {
                'id': 2,
                'type': 'withdrawal',
                'amount': '2500',
                'status': 'pending',
                'created_at': '2026-05-05T18:40:00.000Z',
                'withdrawal': {
                  'transaction_reference': 'wd-ref-2',
                  'contribution': {'name': 'Market Savings'},
                },
              },
            ],
            'current_page': 1,
            'per_page': 5,
            'total': 57,
            'last_page': 12,
          };

      final recent = await repository.recentTransactions();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.path, '/transactions');
      expect(api.calls.single.query, {'page': 1, 'per_page': 5});
      expect(recent.items, hasLength(2));
      expect(recent.perPage, 5);
      expect(recent.page, 1);
      expect(recent.total, 57);
      expect(recent.lastPage, 12);

      final deposit = recent.items[0];
      expect(deposit.isIncoming, isTrue);
      expect(deposit.txnLabel, 'Weekly Ajo');
      expect(deposit.txnAmount, 5000);
      expect(
        deposit.txnDate,
        DateTime.utc(2026, 5, 4, 9, 15),
      );

      final withdrawal = recent.items[1];
      expect(withdrawal.isIncoming, isFalse);
      expect(withdrawal.txnLabel, 'Market Savings');
      expect(withdrawal.txnAmount, 2500);
      expect(
        withdrawal.txnDate,
        DateTime.utc(2026, 5, 5, 18, 40),
      );
    });

    test(
        'row labels fall back to the transaction reference then the type',
        () async {
      api.responses['GET /transactions'] = () => {
            'statusCode': 200,
            'message': 'Transactions Fetched',
            'data': [
              {
                'type': 'withdrawal',
                'amount': 900,
                'withdrawal': {
                  'transaction_reference': 'WD-99001',
                },
              },
              {'type': 'deposit', 'amount': 700},
            ],
            'current_page': 1,
            'per_page': 5,
            'total': 2,
            'last_page': 1,
          };

      final recent = await repository.recentTransactions(perPage: 5);

      expect(api.calls.single.query, {'page': 1, 'per_page': 5});
      expect(recent.items[0].txnLabel, 'WD-99001');
      // No nested beel name or reference — the screen falls back to the
      // transaction type for the label.
      expect(recent.items[1].txnLabel, isNull);
      expect(recent.items[1].isIncoming, isTrue);
    });
  });
}