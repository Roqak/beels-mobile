import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/session_lock_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Resolve the biometric gate first so the router's first redirect sees a
  // settled lock state, then warm the auth bootstrap (token read + profile
  // fetch if a token exists) so the router settles against a known session.
  await container.read(sessionLockControllerProvider.notifier).evaluate();
  container.read(authControllerProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BeelsApp(),
    ),
  );
}