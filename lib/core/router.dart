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
import '../features/beels/screens/invite_nearby_screen.dart';
import '../features/beels/screens/join_invite_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/groups/screens/create_group_screen.dart';
import '../features/groups/screens/group_detail_screen.dart';
import '../features/groups/screens/groups_screen.dart';
import '../features/payments/screens/mandate_list_screen.dart';
import '../features/payments/screens/mandate_setup_screen.dart';
import '../features/beels/screens/my_participation_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/transactions/screens/transactions_screen.dart';
import 'deep_links.dart';
import 'providers.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final joinToken = coldStartJoinToken(ref);
  final router = GoRouter(
    initialLocation: joinToken == null ? '/' : '/join/$joinToken',
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
          returnTo: joinReturnLocation(state.uri.queryParameters['next']),
        ),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) =>
            LockScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          returnTo: joinReturnLocation(state.uri.queryParameters['next']),
        ),
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
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (context, state) => InviteNearbyScreen(
                          id: int.tryParse(
                                  state.pathParameters['id'] ?? '') ??
                              0,
                        ),
                      ),
                    ],
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
      // Public join route: a friend with or without the app lands here from
      // an NFC tap or web link. Authentication is resolved inside the screen.
      GoRoute(
        path: '/join/:token',
        builder: (context, state) =>
            JoinInviteScreen(token: state.pathParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/participation',
        builder: (context, state) => const MyParticipationScreen(),
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

  // Warm-start join links: NFC tap or browser link while the app runs.
  final linkSub = listenForJoinLinks(
    ref,
    (token) => router.go('/join/$token'),
  );
  ref.onDispose(linkSub.cancel);
  ref.onDispose(router.dispose);
  return router;
});

/// The lock route for a user currently at [here], carrying the way back.
@visibleForTesting
String lockLocationFor(String here) => (here == '/' || here.isEmpty)
    ? '/lock'
    : '/lock?from=${Uri.encodeQueryComponent(here)}';

/// Where to go after unlocking. Only in-app paths are honoured, so a crafted
/// link can never bounce the user to another site or back onto the lock.
String resumeLocationFrom(String? from) => (from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith('/lock'))
    ? from
    : '/';

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
    if (locked) return null;
    return resumeLocationFrom(state.uri.queryParameters['from']);
  }
  if (authed && locked) {
    // Remember where the user was so unlocking resumes there.
    return lockLocationFor(state.uri.toString());
  }

  if (authed && _publicLocations.contains(location)) {
    return '/';
  }
  // /join/:token is the public invite landing screen; unauthenticated users
  // get the preview plus a sign-in prompt inside the screen instead of a
  // bare redirect, so the invite context is never lost.
  if (!authed &&
      !_publicLocations.contains(location) &&
      !location.startsWith('/join/')) {
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
