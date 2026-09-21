import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/auth/screens/login_screen.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController({this.onLogin});

  final void Function(String email, String password)? onLogin;
  int loginCalls = 0;

  @override
  Future<Profile?> build() async => null;

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    final handler = onLogin;
    if (handler != null) handler(email, password);
    state = AsyncValue.data(Profile(email: email, firstName: 'Ada'));
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _FakeAuthController controller,
  String? prefilledEmail,
}) async {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => LoginScreen(prefilledEmail: prefilledEmail),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
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

void main() {
  testWidgets('empty submit shows validation errors and does not log in',
      (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller: controller);

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(controller.loginCalls, 0);
  });

  testWidgets('valid credentials navigate to the home route', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField).at(0), 'ada@beels.ng');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret6');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(controller.loginCalls, 1);
    expect(find.text('Enter your email'), findsNothing);
  });

  testWidgets('invalid credentials surface the ApiException message',
      (tester) async {
    final controller = _FakeAuthController(
      onLogin: (_, __) =>
          throw const ApiException('Email does not exist', statusCode: 422),
    );
    await _pumpLogin(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField).at(0), 'ghost@beels.ng');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret6');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Email does not exist'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(controller.loginCalls, 1);
  });

  testWidgets('prefilled email seeds the email field', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(
      tester,
      controller: controller,
      prefilledEmail: 'ada@beels.ng',
    );

    expect(find.text('ada@beels.ng'), findsOneWidget);
  });
}
