import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/biometrics/biometric_authenticator.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/core/storage/session_lock_store.dart';
import 'package:beels_mobile/core/storage/token_store.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/controllers/session_lock_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/auth/screens/lock_screen.dart';

class _FakeTokenStore implements TokenStore {
  String? token = 'stored-token';

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

class _FakeSessionLockStore implements SessionLockStore {
  bool enabledValue = true;

  @override
  Future<bool> enabled() async => enabledValue;

  @override
  Future<void> setEnabled(bool value) async => enabledValue = value;
}

class _FakeAuthenticator implements BiometricAuthenticator {
  _FakeAuthenticator({this.promptResult = true});

  bool promptResult = true;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return promptResult;
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.seed);

  final Profile? seed;
  int logoutCalls = 0;

  @override
  Future<Profile?> build() async => seed;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue.data(null);
  }
}

class _FakeSessionLockController extends SessionLockController {
  _FakeSessionLockController(this.authenticator);

  final _FakeAuthenticator authenticator;

  @override
  SessionLockState build() =>
      const SessionLockState(supported: true, enabled: true, locked: true);

  @override
  Future<bool> unlock() async {
    final ok = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate(reason: 'test');
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }
}

const _seed = Profile(
  email: 'ada@beels.ng',
  firstName: 'Ada',
  lastName: 'Obi',
  phoneNumber: '08012345678',
  status: 'ACTIVE',
  role: 'organizer',
);

Future<void> _pumpLock(
  WidgetTester tester, {
  required _FakeAuthController auth,
  required _FakeAuthenticator authenticator,
}) async {
  final lockController = _FakeSessionLockController(authenticator);
  final router = GoRouter(
    initialLocation: '/lock',
    routes: [
      GoRoute(
        path: '/lock',
        builder: (_, __) => const LockScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME-SENTINEL')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('LOGIN-SENTINEL')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        sessionLockControllerProvider.overrideWith(() => lockController),
        tokenStoreProvider.overrideWithValue(_FakeTokenStore()),
        sessionLockStoreProvider.overrideWithValue(_FakeSessionLockStore()),
        biometricAuthenticatorProvider.overrideWithValue(authenticator),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(); // let initState + post-frame callback run
  await tester.pumpAndSettle(); // let the biometric prompt future settle
}

void main() {
  testWidgets('successful biometric prompt opens the dashboard',
      (tester) async {
    final authenticator = _FakeAuthenticator();
    final auth = _FakeAuthController(_seed);
    await _pumpLock(tester, auth: auth, authenticator: authenticator);

    expect(authenticator.prompts, 1);
    expect(find.text('HOME-SENTINEL'), findsOneWidget);
  });

  testWidgets('failed prompt shows an error and keeps the lock',
      (tester) async {
    final authenticator = _FakeAuthenticator(promptResult: false);
    final auth = _FakeAuthController(_seed);
    await _pumpLock(tester, auth: auth, authenticator: authenticator);

    await tester.pumpAndSettle();
    expect(find.text('HOME-SENTINEL'), findsNothing);
    expect(find.text('We could not verify you. Try again.'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);

    // Tapping Unlock retries and succeeds.
    authenticator.promptResult = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(authenticator.prompts, 2);
    expect(find.text('HOME-SENTINEL'), findsOneWidget);
  });

  testWidgets('password fallback logs out and lands on login with the email',
      (tester) async {
    final authenticator = _FakeAuthenticator(promptResult: false);
    final auth = _FakeAuthController(_seed);
    await _pumpLock(tester, auth: auth, authenticator: authenticator);

    await tester.tap(find.text('Use password instead'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.text('LOGIN-SENTINEL'), findsOneWidget);
  });
}
