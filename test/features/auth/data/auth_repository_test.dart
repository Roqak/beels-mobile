import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/storage/token_store.dart';
import 'package:beels_mobile/features/auth/data/auth_repository.dart';

class _FakeApiClient implements ApiClient {
  final Map<String, Object Function()> handlers = {};
  final List<({String path, Object? body})> calls = [];

  Object _respond(String path) {
    final handler = handlers[path];
    if (handler == null) {
      throw ApiException('Unexpected call to $path', statusCode: 0);
    }
    return handler();
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((path: path, body: query));
    return _respond(path);
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) async {
    calls.add((path: path, body: body));
    return _respond(path);
  }
}

class _FakeTokenStore implements TokenStore {
  String? token;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    token = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

void main() {
  late _FakeApiClient api;
  late _FakeTokenStore tokens;
  late AuthRepository repository;

  setUp(() {
    api = _FakeApiClient();
    tokens = _FakeTokenStore();
    repository = AuthRepository(apiClient: api, tokenStore: tokens);
  });

  group('login', () {
    test('posts password method, stores top-level token, parses profile',
        () async {
      api.handlers['/auth/login'] = () => {
            'statusCode': 200,
            'message': 'Account Login Successfully',
            'access_token': 'jwt-token',
            'data': {
              'email': 'ada@beels.ng',
              'first_name': 'Ada',
              'last_name': 'Obi',
              'status': 'ACTIVE',
              'role': 'organizer',
            },
          };

      final profile =
          await repository.login(email: 'ada@beels.ng', password: 'secret6');

      final call = api.calls.single;
      expect(call.path, '/auth/login');
      expect(call.body, {
        'email': 'ada@beels.ng',
        'method': 'password',
        'password': 'secret6',
      });
      expect(tokens.token, 'jwt-token');
      expect(profile.email, 'ada@beels.ng');
      expect(profile.firstName, 'Ada');
      expect(profile.lastName, 'Obi');
      expect(profile.status, 'ACTIVE');
      expect(profile.role, 'organizer');
    });

    test('maps a 422 error message and stores no token', () async {
      api.handlers['/auth/login'] = () =>
          throw const ApiException('Email does not exist', statusCode: 422);

      await expectLater(
        repository.login(email: 'ghost@beels.ng', password: 'secret6'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Email does not exist')
            .having((e) => e.statusCode, 'statusCode', 422)),
      );
      expect(tokens.token, isNull);
    });

    test('fails when the envelope has no access_token', () async {
      api.handlers['/auth/login'] = () => {
            'statusCode': 200,
            'message': 'Account Login Successfully',
            'data': {'email': 'ada@beels.ng'},
          };

      await expectLater(
        repository.login(email: 'ada@beels.ng', password: 'secret6'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, isNull);
    });
  });

  test('register posts the password-method payload', () async {
    api.handlers['/auth/register'] = () => {
          'statusCode': 200,
          'message': 'User Registered Successfully',
          'data': {'email': 'ada@beels.ng'},
        };

    await repository.register(
      firstName: 'Ada',
      lastName: 'Obi',
      email: 'ada@beels.ng',
      phoneNumber: '08012345678',
      password: 'secret6',
    );

    expect(api.calls.single.body, {
      'first_name': 'Ada',
      'last_name': 'Obi',
      'email': 'ada@beels.ng',
      'phone_number': '08012345678',
      'method': 'password',
      'password': 'secret6',
    });
  });

  test('requestPasswordReset posts the email', () async {
    api.handlers['/auth/password/reset/email'] = () =>
        {'statusCode': 200, 'message': 'Password Reset Token Sent', 'data': {}};

    await repository.requestPasswordReset('ada@beels.ng');

    expect(api.calls.single.body, {'email': 'ada@beels.ng'});
  });

  test('fetchProfile parses the envelope', () async {
    api.handlers['/auth/profile'] = () => {
          'statusCode': 200,
          'message': 'User Profile Fetched',
          'data': {
            'phone_number': '08012345678',
            'email': 'ada@beels.ng',
            'first_name': 'Ada',
            'last_name': 'Obi',
            'status': 'ACTIVE',
          },
        };

    final profile = await repository.fetchProfile();

    expect(api.calls.single.path, '/auth/profile');
    expect(profile.firstName, 'Ada');
    expect(profile.role, isNull);
  });

  test('updateProfile sends only provided fields and parses the result',
      () async {
    api.handlers['/auth/profile'] = () => {
          'statusCode': 200,
          'message': 'Profile Updated Successfully',
          'data': {
            'email': 'ada@beels.ng',
            'phone_number': '08099999999',
            'first_name': 'Ada',
            'last_name': 'Obi',
            'status': 'ACTIVE',
          },
        };

    final profile = await repository.updateProfile(
      firstName: 'Ada',
      phoneNumber: '08099999999',
    );

    expect(api.calls.single.body, {
      'first_name': 'Ada',
      'phone_number': '08099999999',
    });
    expect(profile.phoneNumber, '08099999999');
  });

  test('changePassword sends old, new and matching confirm fields', () async {
    api.handlers['/auth/password/change'] = () =>
        {'statusCode': 200, 'message': 'Password Changed Successfully', 'data': {}};

    await repository.changePassword(oldPassword: 'old6chars', newPassword: 'new6chars');

    expect(api.calls.single.body, {
      'old_password': 'old6chars',
      'new_password': 'new6chars',
      'confirm_new_password': 'new6chars',
    });
  });

  test('logout clears the token even when the request fails', () async {
    tokens.token = 'jwt-token';
    api.handlers['/auth/logout'] = () =>
        throw const ApiException('You appear to be offline. Check your connection.',
            statusCode: 0);

    await repository.logout();

    expect(tokens.token, isNull);
    expect(tokens.clears, 1);
  });
}