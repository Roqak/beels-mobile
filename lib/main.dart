import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/session_lock_controller.dart';

/// Refuses to run a release build that would silently talk to the dev
/// backend: release binaries must be built with an explicit
/// --dart-define=BEELS_BASE_URL=... (and BEELS_FRONTEND_URL if links differ).
void _assertReleaseConfig() {
  if (!const bool.fromEnvironment('dart.vm.product')) return;
  if (!AppConfig.baseUrl.contains('dev-production-80a4.up.railway.app')) {
    return;
  }
  throw StateError(
    'Release build is pointing at the dev backend. Rebuild with '
    '--dart-define=BEELS_BASE_URL=https://<production-api>. '
    'Current baseUrl: ${AppConfig.baseUrl}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _assertReleaseConfig();

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
