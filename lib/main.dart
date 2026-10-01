import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/deep_links.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/session_lock_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cold-start join links must be read before the router builds, otherwise
  // the first navigation lands on the dashboard and the invite is lost.
  Uri? initialUri;
  try {
    initialUri = await AppLinks().getInitialLink();
  } on Object {
    initialUri = null;
  }

  final container = ProviderContainer(
    overrides: [
      if (initialUri != null)
        initialJoinUriProvider.overrideWithValue(initialUri),
    ],
  );
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