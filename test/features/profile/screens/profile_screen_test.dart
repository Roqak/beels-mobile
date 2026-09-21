import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/biometrics/biometric_authenticator.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/controllers/session_lock_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/profile/screens/profile_screen.dart';

const _seed = Profile(
  email: 'ada@beels.ng',
  firstName: 'Ada',
  lastName: 'Obi',
  phoneNumber: '08012345678',
  status: 'ACTIVE',
  role: 'organizer',
);

class _FakeProfileController extends AuthController {
  _FakeProfileController({this.seed, this.buildError});

  final Profile? seed;
  final Object? buildError;
  final List<Map<String, String?>> updateCalls = [];
  int changeCalls = 0;
  List<String> lastChange = const [];
  int logoutCalls = 0;

  @override
  Future<Profile?> build() async {
    final error = buildError;
    if (error != null) throw error;
    return seed;
  }

  @override
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    updateCalls.add({
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
    });
    final base = seed ?? _seed;
    state = AsyncValue.data(
      Profile(
        email: base.email,
        firstName: firstName ?? base.firstName,
        lastName: lastName ?? base.lastName,
        phoneNumber: phoneNumber ?? base.phoneNumber,
        status: base.status,
        role: base.role,
      ),
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    changeCalls++;
    lastChange = [oldPassword, newPassword];
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue.data(null);
  }
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _FakeProfileController controller,
}) async {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
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
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _flushSnackbars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

SwitchListTile _switch(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

void main() {
  testWidgets('renders profile fields and status', (tester) async {
    await _pumpProfile(tester, controller: _FakeProfileController(seed: _seed));

    expect(find.text('Ada Obi'), findsOneWidget);
    expect(find.text('ada@beels.ng'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('error state shows the ApiException message', (tester) async {
    await _pumpProfile(
      tester,
      controller: _FakeProfileController(
        seed: null,
        buildError: const ApiException(
          'You appear to be offline. Check your connection.',
          statusCode: 0,
        ),
      ),
    );

    expect(
      find.text('You appear to be offline. Check your connection.'),
      findsOneWidget,
    );
  });

  testWidgets('saving the edit sheet updates the header and confirms',
      (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Adanna');
    await tester.enterText(find.byType(TextFormField).at(2), '08099999999');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.updateCalls.single['firstName'], 'Adanna');
    expect(controller.updateCalls.single['lastName'], 'Obi');
    expect(controller.updateCalls.single['phoneNumber'], '08099999999');
    expect(find.text('Adanna Obi'), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);
    // Sheet closed after a successful save.
    expect(find.text('Save changes'), findsNothing);
    await _flushSnackbars(tester);
  });

  testWidgets('change password validation blocks mismatched confirmation',
      (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'old6chars');
    await tester.enterText(find.byType(TextFormField).at(1), 'new6chars');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tester.ensureVisible(find.text('Change password').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password').last);
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(controller.changeCalls, 0);
  });

  testWidgets('change password submits, closes the sheet and confirms',
      (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'old6chars');
    await tester.enterText(find.byType(TextFormField).at(1), 'new6chars');
    await tester.enterText(find.byType(TextFormField).at(2), 'new6chars');
    await tester.ensureVisible(find.text('Change password').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password').last);
    await tester.pumpAndSettle();

    expect(controller.changeCalls, 1);
    expect(controller.lastChange, ['old6chars', 'new6chars']);
    expect(find.text('Password changed'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await _flushSnackbars(tester);
  });

  testWidgets('logout requires confirmation then signs out', (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    // The sign-out tile sits below the fold in the default test viewport.
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pumpAndSettle();
    expect(controller.logoutCalls, 0);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    // The dialog title is also "Log out"; the action button is the last match.
    await tester.tap(find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Log out'),
        )
        .last);
    await tester.pumpAndSettle();

    expect(controller.logoutCalls, 1);
    expect(find.text('LOGIN-SENTINEL'), findsOneWidget);
  });

  testWidgets('biometric toggle prompts, then persists the opt-in',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator();
    final lock = _FakeSessionLockController(authenticator);
    await _pumpBiometricSection(
      tester,
      controller: _FakeProfileController(seed: _seed),
      lock: lock,
      authenticator: authenticator,
    );

    expect(find.text('Biometric login'), findsOneWidget);
    expect(find.text('Not available on this device.'), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(_switch(tester).value, isFalse);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(authenticator.prompts, 1);
    expect(_switch(tester).value, isTrue);
  });

  testWidgets('failed biometric prompt leaves the toggle off with an error',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator(promptResult: false);
    final lock = _FakeSessionLockController(authenticator);
    await _pumpBiometricSection(
      tester,
      controller: _FakeProfileController(seed: _seed),
      lock: lock,
      authenticator: authenticator,
    );

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await _flushSnackbars(tester);

    expect(authenticator.prompts, 1);
    expect(_switch(tester).value, isFalse);
    expect(
      find.text('Biometric verification failed. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('unsupported devices show a disabled toggle', (tester) async {
    final authenticator = _FakeBiometricAuthenticator(available: false);
    final lock = _FakeSessionLockController(
      authenticator,
      supported: false,
    );
    await _pumpBiometricSection(
      tester,
      controller: _FakeProfileController(seed: _seed),
      lock: lock,
      authenticator: authenticator,
    );

    expect(find.text('Not available on this device.'), findsOneWidget);
    expect(_switch(tester).onChanged, isNull);
  });

  testWidgets('auto-lock delay can be chosen once biometrics are on',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator();
    final lock = _FakeSessionLockController(authenticator);
    await _pumpBiometricSection(
      tester,
      controller: _FakeProfileController(seed: _seed),
      lock: lock,
      authenticator: authenticator,
    );

    // Hidden until biometric login is on.
    expect(find.text('Lock after'), findsNothing);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Lock after'), findsOneWidget);
    expect(find.text('1 minute'), findsOneWidget);

    await tester.ensureVisible(find.text('Lock after'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock after'));
    await tester.pumpAndSettle();

    // Sheet lists every choice.
    expect(find.text('Right away'), findsOneWidget);
    expect(find.text('30 seconds'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);

    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();

    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.text('1 minute'), findsNothing);
  });
}

Future<void> _pumpBiometricSection(
  WidgetTester tester, {
  required _FakeProfileController controller,
  required _FakeSessionLockController lock,
  required _FakeBiometricAuthenticator authenticator,
}) async {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
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
        authControllerProvider.overrideWith(() => controller),
        sessionLockControllerProvider.overrideWith(() => lock),
        biometricAuthenticatorProvider.overrideWithValue(authenticator),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator(
      {this.available = true, this.promptResult = true});

  bool available;
  bool promptResult;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return promptResult;
  }
}

class _FakeSessionLockController extends SessionLockController {
  _FakeSessionLockController(this.authenticator, {this.supported = true});

  final _FakeBiometricAuthenticator authenticator;
  final bool supported;

  @override
  SessionLockState build() => SessionLockState(
        supported: supported,
        enabled: false,
        locked: false,
      );

  @override
  Future<bool> setEnabled(bool value) async {
    if (value && !state.supported) return false;
    if (value) {
      final ok = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: 'test');
      if (!ok) return false;
    }
    state = state.copyWith(enabled: value);
    return true;
  }
}
