import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

/// Root widget: themed MaterialApp bound to the go_router config.
class BeelsApp extends ConsumerWidget {
  const BeelsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Beels',
      debugShowCheckedModeBanner: false,
      theme: beelsTheme(context),
      routerConfig: ref.watch(routerProvider),
    );
  }
}