import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
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

  testWidgets('saving the edit form updates the header and confirms',
      (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField).at(0), 'Adanna');
    await tester.enterText(find.byType(TextFormField).at(2), '08099999999');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.updateCalls.single['firstName'], 'Adanna');
    expect(controller.updateCalls.single['lastName'], 'Obi');
    expect(controller.updateCalls.single['phoneNumber'], '08099999999');
    expect(find.text('Adanna Obi'), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);
    await _flushSnackbars(tester);
  });

  testWidgets('change password validation blocks mismatched confirmation',
      (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField).at(3), 'old6chars');
    await tester.enterText(find.byType(TextFormField).at(4), 'new6chars');
    await tester.enterText(find.byType(TextFormField).at(5), 'different');
    // The password form sits below the fold in the default test viewport.
    await tester.ensureVisible(find.text('Change password').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password').last);
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(controller.changeCalls, 0);
  });

  testWidgets('change password submits and clears the fields', (tester) async {
    final controller = _FakeProfileController(seed: _seed);
    await _pumpProfile(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField).at(3), 'old6chars');
    await tester.enterText(find.byType(TextFormField).at(4), 'new6chars');
    await tester.enterText(find.byType(TextFormField).at(5), 'new6chars');
    await tester.ensureVisible(find.text('Change password').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password').last);
    await tester.pumpAndSettle();

    expect(controller.changeCalls, 1);
    expect(controller.lastChange, ['old6chars', 'new6chars']);
    expect(find.text('Password changed'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(3))
          .controller
          ?.text,
      '',
    );
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
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Log out'),
    ).last);
    await tester.pumpAndSettle();

    expect(controller.logoutCalls, 1);
    expect(find.text('LOGIN-SENTINEL'), findsOneWidget);
  });
}