import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Warm the auth bootstrap (token read + profile fetch if a token exists)
  // so the router's first redirect settles against a known session.
  container.read(authControllerProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BeelsApp(),
    ),
  );
}