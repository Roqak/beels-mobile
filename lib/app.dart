import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

/// Root widget: themed MaterialApp bound to the go_router config. Follows the
/// system light/dark setting; on a change the palette is swapped and the tree
/// is rebuilt (navigation state lives in the router, so it survives).
class BeelsApp extends ConsumerStatefulWidget {
  const BeelsApp({super.key});

  @override
  ConsumerState<BeelsApp> createState() => _BeelsAppState();
}

class _BeelsAppState extends ConsumerState<BeelsApp>
    with WidgetsBindingObserver {
  late Brightness _brightness =
      SchedulerBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    if (next != _brightness) setState(() => _brightness = next);
  }

  @override
  Widget build(BuildContext context) {
    BeelsColors.apply(_brightness);
    return KeyedSubtree(
      key: ValueKey(_brightness),
      child: MaterialApp.router(
        title: 'Beels',
        debugShowCheckedModeBanner: false,
        theme: beelsTheme(context),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
