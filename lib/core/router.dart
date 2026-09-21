import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/controllers/session_lock_controller.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/beels/screens/beel_detail_screen.dart';
import '../features/beels/screens/beels_screen.dart';
import '../features/beels/screens/create_beel_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/groups/screens/create_group_screen.dart';
import '../features/groups/screens/group_detail_screen.dart';
import '../features/groups/screens/groups_screen.dart';
import '../features/payments/screens/mandate_list_screen.dart';
import '../features/payments/screens/mandate_setup_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/transactions/screens/transactions_screen.dart';
import 'providers.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: ref.watch(authListenableProvider),
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          prefilledEmail: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/beels',
                builder: (context, state) => const BeelsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const CreateBeelScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                      return BeelDetailScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (context, state) => const GroupsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                      return GroupDetailScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/mandates',
        builder: (context, state) => const MandateListScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            builder: (context, state) => const MandateSetupScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

const _publicLocations = {'/login', '/register', '/forgot-password'};

String? _redirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authControllerProvider);
  final location = state.matchedLocation;

  // First boot: token read / profile fetch still in flight. Park on the
  // splash screen instead of guessing, so protected screens never mount
  // without a known session.
  final bootstrapping = auth.isLoading && auth.valueOrNull == null;
  if (bootstrapping) {
    return location == '/splash' ? null : '/splash';
  }

  final authed = auth.valueOrNull != null;
  if (location == '/splash') {
    return authed ? '/' : '/login';
  }

  // A biometric-locked session must land on the lock screen before any
  // protected content mounts.
  final locked = ref.read(sessionLockControllerProvider).locked;
  if (location == '/lock') {
    if (!authed) return '/login';
    return locked ? null : '/';
  }
  if (authed && locked) {
    return '/lock';
  }

  if (authed && _publicLocations.contains(location)) {
    return '/';
  }
  if (!authed && !_publicLocations.contains(location)) {
    return '/login';
  }
  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Beels',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BeelsColors.ink0,
                  ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
