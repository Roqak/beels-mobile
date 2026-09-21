import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/storage/token_store.dart';

class _FakeTokenStore implements TokenStore {
  String? token;
  int clearCount = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async {
    clearCount++;
    token = null;
  }
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ApiClient _client({
  required _FakeTokenStore tokenStore,
  required ResponseBody Function(RequestOptions options) handler,
  required List<int> unauthorizedCalls,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.httpClientAdapter = _StubAdapter(handler);
  return ApiClient(
    tokenStore: tokenStore,
    onUnauthorized: () => unauthorizedCalls.add(1),
    dio: dio,
  );
}

void main() {
  test('adds bearer header when a token exists', () async {
    final tokenStore = _FakeTokenStore()..token = 'tok123';
    final unauthorized = <int>[];
    RequestOptions? captured;
    final client = _client(
      tokenStore: tokenStore,
      unauthorizedCalls: unauthorized,
      handler: (options) {
        captured = options;
        return ResponseBody.fromString(
          jsonEncode({'data': {'ok': true}}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      },
    );

    final result = await client.get('/me');

    expect(captured!.headers['Authorization'], 'Bearer tok123');
    expect((result as Map)['data']['ok'], isTrue);
    expect(unauthorized, isEmpty);
  });

  test('omits Authorization when no token exists', () async {
    final tokenStore = _FakeTokenStore();
    final unauthorized = <int>[];
    RequestOptions? captured;
    final client = _client(
      tokenStore: tokenStore,
      unauthorizedCalls: unauthorized,
      handler: (options) {
        captured = options;
        return ResponseBody.fromString(jsonEncode({'data': []}), 200);
      },
    );

    await client.get('/me');

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('sends query parameters and JSON bodies', () async {
    final tokenStore = _FakeTokenStore();
    final unauthorized = <int>[];
    final requests = <RequestOptions>[];
    final client = _client(
      tokenStore: tokenStore,
      unauthorizedCalls: unauthorized,
      handler: (options) {
        requests.add(options);
        return ResponseBody.fromString(jsonEncode({'data': null}), 200);
      },
    );

    await client.get('/items', query: {'page': 2});
    await client.post('/beels', body: {'name': 'Trip'});

    expect(requests, hasLength(2));
    expect(requests[0].uri.path.endsWith('/items'), isTrue);
    expect(requests[0].queryParameters['page'], 2);
    expect(requests[1].method, 'POST');
    expect(requests[1].data, {'name': 'Trip'});
  });

  test('401 clears the token and fires onUnauthorized once', () async {
    final tokenStore = _FakeTokenStore()..token = 'expired';
    final unauthorized = <int>[];
    final client = _client(
      tokenStore: tokenStore,
      unauthorizedCalls: unauthorized,
      handler: (options) => ResponseBody.fromString(
        jsonEncode({'statusCode': 401, 'message': 'Unauthenticated.'}),
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ),
    );

    await expectLater(
      client.get('/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Unauthenticated.'),
      ),
    );

    expect(tokenStore.token, isNull);
    expect(tokenStore.clearCount, 1);
    expect(unauthorized, hasLength(1));
  });

  test('offline failures map to the offline message with status 0', () async {
    final tokenStore = _FakeTokenStore();
    final unauthorized = <int>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _StubAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'boom',
      ),
    );
    final client = ApiClient(
      tokenStore: tokenStore,
      onUnauthorized: () => unauthorized.add(1),
      dio: dio,
    );

    await expectLater(
      client.get('/me'),
      throwsA(
        isA<ApiException>()
            .having(
              (e) => e.message,
              'message',
              'You appear to be offline. Check your connection.',
            )
            .having((e) => e.statusCode, 'statusCode', 0),
      ),
    );
    expect(unauthorized, isEmpty);
  });

  test('422 validation lists are joined in the message', () async {
    final tokenStore = _FakeTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _StubAdapter(
      (options) => ResponseBody.fromString(
        jsonEncode({
          'message': ['Name is required', 'Amount must be positive'],
        }),
        422,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ),
    );
    final client = ApiClient(
      tokenStore: tokenStore,
      onUnauthorized: () {},
      dio: dio,
    );

    await expectLater(
      client.post('/groups', body: {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Name is required; Amount must be positive',
        ),
      ),
    );
  });
}