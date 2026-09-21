import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:beels_mobile/features/dashboard/screens/dashboard_screen.dart';

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository();

  @override
  Future<DashboardAnalytics> analytics() async {
    return const DashboardAnalytics(
      totalDeposited: 150000,
      totalWithdrawn: 40000,
      totalContributions: 12,
      totalTransactions: 57,
    );
  }

  @override
  Future<Paginated<Map<String, dynamic>>> recentTransactions({
    int page = 1,
    int perPage = 5,
  }) async {
    return Paginated.parse<Map<String, dynamic>>(
      {
        'statusCode': 200,
        'data': [
          {
            'id': 1,
            'type': 'deposit',
            'amount': 5000,
            'status': 'completed',
            'created_at': '2026-05-04T09:15:00.000Z',
            'deposit': {
              'contributor': {
                'contribution': {'name': 'Weekly Ajo'},
              },
            },
          },
          {
            'id': 2,
            'type': 'withdrawal',
            'amount': 2500,
            'status': 'pending',
            'created_at': '2026-05-05T18:40:00.000Z',
            'withdrawal': {
              'contribution': {'name': 'Market Savings'},
            },
          },
        ],
        'current_page': 1,
        'per_page': 5,
        'total': 2,
        'last_page': 1,
      },
      (item) =>
          item is Map ? item.cast<String, dynamic>() : <String, dynamic>{},
    );
  }
}

class _FakeBeelsRepository implements BeelsRepository {
  @override
  Future<Paginated<Contribution>> list({int page = 1, int perPage = 20}) async {
    return Paginated<Contribution>(
      items: [
        Contribution(
          id: 1,
          name: 'Weekly Ajo',
          unitAmount: 5000,
          status: 'active',
          recurrenceType: 'weekly',
          dayOfWeek: 'friday',
          nextOccurrence: DateTime(2026, 6, 5),
        ),
        Contribution(
          id: 2,
          name: 'Rent Pool',
          unitAmount: 20000,
          status: 'active',
          recurrenceType: 'monthly',
          dayOfMonth: 1,
          nextOccurrence: DateTime(2026, 7, 1),
        ),
      ],
      page: 1,
      perPage: 20,
      total: 2,
      lastPage: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededAuthController extends AuthController {
  @override
  Future<Profile?> build() async {
    return const Profile(
      email: 'ade@example.com',
      firstName: 'Ade',
      lastName: 'Balo',
    );
  }
}

Widget _testApp() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) =>
            const Scaffold(body: Text('TRANSACTIONS_PAGE')),
      ),
      GoRoute(
        path: '/beels/new',
        builder: (context, state) =>
            const Scaffold(body: Text('NEW_BEEL_PAGE')),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('PROFILE_PAGE')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(
        _FakeDashboardRepository(),
      ),
      beelsRepositoryProvider.overrideWithValue(_FakeBeelsRepository()),
      authControllerProvider.overrideWith(_SeededAuthController.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders greeting, stat cards and recent transactions',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Hello, Ade'), findsOneWidget);
    expect(find.text('Total Deposited'), findsOneWidget);
    expect(find.text('Total Withdrawn'), findsOneWidget);
    expect(find.text('Beels'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('₦150,000'), findsOneWidget);
    expect(find.text('₦40,000'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('57'), findsOneWidget);

    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Weekly Ajo'), findsNWidgets(2));
    expect(find.text('Rent Pool'), findsOneWidget);

    expect(find.text('Recent transactions'), findsOneWidget);
    expect(find.text('Market Savings'), findsOneWidget);
    // core money: '+' prefix for incoming, U+2212 minus for outgoing.
    expect(find.text('+₦5,000'), findsOneWidget);
    expect(find.text('−₦2,500'), findsOneWidget);
  });

  testWidgets('View all navigates to /transactions', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('TRANSACTIONS_PAGE'), findsOneWidget);
  });

  testWidgets('New beel quick action navigates to /beels/new', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New beel'));
    await tester.pumpAndSettle();

    expect(find.text('NEW_BEEL_PAGE'), findsOneWidget);
  });

  testWidgets('avatar navigates to /profile', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('AB'));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE_PAGE'), findsOneWidget);
  });

  testWidgets('eye icon hides and shows balances', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('₦150,000'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hide balances'));
    await tester.pumpAndSettle();
    expect(find.text('₦150,000'), findsNothing);
    expect(find.text('₦40,000'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Show balances'));
    await tester.pumpAndSettle();
    expect(find.text('₦150,000'), findsOneWidget);
  });
}
