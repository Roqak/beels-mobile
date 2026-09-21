import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/core/storage/token_store.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/data/auth_repository.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';

Profile _profile({String firstName = 'Ada', String? role = 'organizer'}) =>
    Profile(
      email: 'ada@beels.ng',
      firstName: firstName,
      lastName: 'Obi',
      phoneNumber: '08012345678',
      status: 'ACTIVE',
      role: role,
    );

class _FakeAuthRepository implements AuthRepository {
  Profile loginResult = _profile();
  Object? loginError;
  Object? registerError;
  Profile fetchResult = _profile();
  Object? fetchError;
  Profile updateResult = _profile(role: null);
  final List<({String path, Map<String, dynamic> body})> calls = [];

  @override
  Future<Profile> login({
    required String email,
    required String password,
  }) async {
    calls.add((path: 'login', body: {'email': email}));
    final error = loginError;
    if (error != null) throw error;
    return loginResult;
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    calls.add((path: 'register', body: {'email': email}));
    final error = registerError;
    if (error != null) throw error;
  }

  @override
  Future<Profile> fetchProfile() async {
    calls.add((path: 'fetchProfile', body: {}));
    final error = fetchError;
    if (error != null) throw error;
    return fetchResult;
  }

  @override
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    calls.add((
      path: 'updateProfile',
      body: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
      },
    ));
    final base = updateResult;
    return Profile(
      email: base.email,
      firstName: firstName ?? base.firstName,
      lastName: lastName ?? base.lastName,
      phoneNumber: phoneNumber ?? base.phoneNumber,
      status: base.status,
      role: base.role,
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    calls.add((path: 'changePassword', body: {'old': oldPassword}));
  }

  @override
  Future<void> logout() async {
    calls.add((path: 'logout', body: {}));
    // Mirrors AuthRepository.logout: sign-out always drops the local token.
    tokens?.clear();
  }

  TokenStore? tokens;

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add((path: 'requestPasswordReset', body: {'email': email}));
  }
}

class _FakeTokenStore implements TokenStore {
  String? token = 'stored-token';
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
  late _FakeAuthRepository repository;
  late _FakeTokenStore tokens;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeAuthRepository();
    tokens = _FakeTokenStore();
    repository.tokens = tokens;
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      tokenStoreProvider.overrideWithValue(tokens),
    ]);
  });

  tearDown(() => container.dispose());

  Future<AuthController> notifier() async {
    await container.read(authControllerProvider.future);
    return container.read(authControllerProvider.notifier);
  }

  test('bootstrap with no token resolves to unauthenticated', () async {
    tokens.token = null;

    final controller = await notifier();

    expect(controller.state.valueOrNull, isNull);
    expect(controller.isAuthenticated, isFalse);
    expect(repository.calls, isEmpty);
  });

  test('bootstrap with a token fetches the profile', () async {
    final controller = await notifier();

    expect(controller.state.valueOrNull?.firstName, 'Ada');
    expect(controller.isAuthenticated, isTrue);
  });

  test('bootstrap clears the token silently on 401', () async {
    repository.fetchError =
        const ApiException('Session expired', statusCode: 401);

    final controller = await notifier();

    expect(controller.state.valueOrNull, isNull);
    expect(tokens.token, isNull);
    expect(tokens.clears, 1);
  });

  test('login stores token and exposes profile', () async {
    repository.loginResult = _profile(firstName: 'Chidi');
    final controller = await notifier();

    await controller.login(email: 'ada@beels.ng', password: 'secret6');

    expect(controller.state.valueOrNull?.firstName, 'Chidi');
    expect(controller.isAuthenticated, isTrue);
    expect(tokens.token, 'stored-token');
  });

  test('failed login rethrows ApiException and keeps state unauthenticated',
      () async {
    repository.loginError =
        const ApiException('Email does not exist', statusCode: 422);
    final controller = await notifier();

    await expectLater(
      controller.login(email: 'ghost@beels.ng', password: 'secret6'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Email does not exist')),
    );

    // Riverpod 2.6 keeps the previous value visible on the error state;
    // the contract under test is "treated as unauthenticated".
    expect(controller.state.unwrapPrevious().valueOrNull, isNull);
    expect(controller.isAuthenticated, isFalse);
  });

  test('registerThenLogin registers first, then logs in', () async {
    final controller = await notifier();
    repository.calls.clear();

    await controller.registerThenLogin(
      firstName: 'Ada',
      lastName: 'Obi',
      email: 'ada@beels.ng',
      phoneNumber: '08012345678',
      password: 'secret6',
    );

    expect(
      repository.calls.map((c) => c.path).toList(),
      ['register', 'login'],
    );
    expect(controller.isAuthenticated, isTrue);
  });

  test('registerThenLogin surfaces register errors and skips login', () async {
    repository.registerError =
        const ApiException('Email already exists', statusCode: 422);
    final controller = await notifier();

    await expectLater(
      controller.registerThenLogin(
        firstName: 'Ada',
        lastName: 'Obi',
        email: 'taken@beels.ng',
        phoneNumber: '08012345678',
        password: 'secret6',
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Email already exists')),
    );

    expect(controller.isAuthenticated, isFalse);
    expect(
      repository.calls.map((c) => c.path),
      isNot(contains('login')),
    );
  });

  test('updateProfile merges result and preserves role', () async {
    final controller = await notifier();

    await controller.updateProfile(
      firstName: 'Adanna',
      phoneNumber: '08099999999',
    );

    final state = controller.state.valueOrNull!;
    expect(state.firstName, 'Adanna');
    expect(state.lastName, 'Obi');
    expect(state.phoneNumber, '08099999999');
    expect(state.role, 'organizer');
  });

  test('logout clears state and token', () async {
    final controller = await notifier();

    await controller.logout();

    expect(controller.state.valueOrNull, isNull);
    expect(controller.isAuthenticated, isFalse);
    expect(tokens.token, isNull);
    expect(repository.calls.last.path, 'logout');
  });

  test('changePassword delegates to the repository', () async {
    final controller = await notifier();

    await controller.changePassword(
      oldPassword: 'old6chars',
      newPassword: 'new6chars',
    );

    expect(repository.calls.last.path, 'changePassword');
    expect(repository.calls.last.body['old'], 'old6chars');
  });
}
