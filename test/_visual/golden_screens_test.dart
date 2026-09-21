// THROWAWAY visual-verification harness (not part of the permanent suite).
// Renders key screens with realistic fixtures and writes PNG goldens.
// Run: flutter test test/_visual --update-goldens
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/core/theme.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/auth/screens/login_screen.dart';
import 'package:beels_mobile/features/beels/controllers/beels_controllers.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/screens/beel_detail_screen.dart';
import 'package:beels_mobile/features/beels/screens/beels_screen.dart';
import 'package:beels_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:beels_mobile/features/dashboard/screens/dashboard_screen.dart';

Widget _themed(Widget child) {
  return Builder(
    builder: (context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beelsTheme(context),
      home: Theme(data: beelsTheme(context), child: child),
    ),
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> build() async => _profile;
}

class _FakeDashboardController extends DashboardController {
  @override
  FutureOr<DashboardData> build() async => DashboardData(
        analytics: const DashboardAnalytics(
          totalDeposited: 412500,
          totalWithdrawn: 96000,
          totalContributions: 24,
          totalTransactions: 118,
        ),
        recent: Paginated.parse<Map<String, dynamic>>(
          {
            'statusCode': 200,
            'data': [
            {
              'id': 41,
              'type': 'deposit',
              'amount': 15000,
              'status': 'completed',
              'created_at': '2026-09-18T09:15:00.000Z',
              'deposit': {
                'contributor': {
                  'contribution': {'name': 'Family Savings'},
                },
              },
            },
            {
              'id': 40,
              'type': 'withdrawal',
              'amount': 8000,
              'status': 'pending',
              'created_at': '2026-09-17T18:40:00.000Z',
              'withdrawal': {
                'contribution': {'name': 'Market Savings'},
              },
            },
            {
              'id': 39,
              'type': 'deposit',
              'amount': 5000,
              'status': 'completed',
              'created_at': '2026-09-16T12:05:00.000Z',
              'deposit': {
                'contributor': {
                  'contribution': {'name': 'Weekly Ajo'},
                },
              },
            },
          ],
          'current_page': 1,
          'per_page': 5,
          'total': 3,
          'last_page': 1,
          },
          (item) => item is Map ? item.cast<String, dynamic>() : <String, dynamic>{},
        ),
      );
}

class _FakeBeelsListController extends BeelsListController {
  @override
  Future<BeelsListState> build() async => BeelsListState(
        items: [
          Contribution.fromJson({
            'id': 27,
            'name': 'Family Savings',
            'unit_amount': 5000,
            'total_amount': 60000,
            'status': 'active',
            'recurrence_type': 'weekly',
            'day_of_week': 'monday',
            'next_occurrence': '2026-09-21T00:00:00.000Z',
            'occurrences': 12,
            'contribution_mode': 'closed',
          }),
          Contribution.fromJson({
            'id': 26,
            'name': 'Birthday Fund',
            'unit_amount': 2500,
            'total_amount': 25000,
            'status': 'pending',
            'recurrence_type': 'one_time',
            'contribution_mode': 'open_link',
            'payment_link_token': 'tok_abc123',
          }),
        ],
        page: 1,
        lastPage: 1,
        total: 2,
      );

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _FakeBeelDetailController extends BeelDetailController {
  @override
  FutureOr<Contribution> build(int arg) => Contribution.fromJson({
        'id': 27,
        'name': 'Family Savings',
        'unit_amount': '5000',
        'total_amount': '60000',
        'amount_paid': '25000',
        'status': 'active',
        'recurrence_type': 'weekly',
        'day_of_week': 'monday',
        'next_occurrence': '2026-09-21T00:00:00.000Z',
        'occurrences': 12,
        'contribution_mode': 'closed',
        'contributors': [
          {
            'id': 101,
            'first_name': 'Ada',
            'last_name': 'Okafor',
            'email': 'ada@beels.test',
            'unit_amount': '5000',
            'amount_paid': '15000',
            'status': 'active',
          },
          {
            'id': 102,
            'first_name': 'Bode',
            'last_name': 'Aliu',
            'email': 'bode@beels.test',
            'unit_amount': '5000',
            'amount_paid': '10000',
            'status': 'active',
          },
        ],
        'beneficiaries': [
          {
            'id': 201,
            'name': 'Ada Okafor',
            'type': 'bank_transfer',
            'account_number': '0123456789',
            'bank_code': '058',
            'amount': '30000',
            'status': 'pending',
          },
          {
            'id': 202,
            'name': 'Bode Aliu',
            'type': 'bank_transfer',
            'account_number': '0234567891',
            'bank_code': '058',
            'amount': '30000',
            'status': 'pending',
          },
        ],
      });

  @override
  Future<void> refresh() async {}

  @override
  Future<void> cancelBeel() async {}
}

void main() {
  setUpAll(() async {
    // Register the bundled brand TTFs (assets/google_fonts) eagerly:
    // google_fonts loads lazily per first paint, which races the golden
    // capture and lays text out with fallback squares. Also block the
    // runtime network fetch (test HttpClients are mocked and would throw).
    GoogleFonts.config.allowRuntimeFetching = false;
    // google_fonts registers families as '<Family>_<variant>'
    // ('Inter_regular', 'Inter_600', ...) - match those exactly.
    const weights = {
      'regular': 'Regular',
      '500': 'Medium',
      '600': 'SemiBold',
      '700': 'Bold',
    };
    for (final family in const ['Inter', 'BricolageGrotesque']) {
      final loader = FontLoader('$family' '_regular');
      final first = await rootBundle
          .load('assets/google_fonts/$family-Regular.ttf');
      loader.addFont(Future.value(first));
      await loader.load();
      for (final weight in const ['500', '600', '700']) {
        final file = weights[weight]!;
        final data =
            await rootBundle.load('assets/google_fonts/$family-$file.ttf');
        final variantLoader = FontLoader('$family' '_$weight');
        variantLoader.addFont(Future.value(data));
        await variantLoader.load();
      }
    }
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: _themed(child)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login screen golden', (tester) async {
    await pumpScreen(
      tester,
      const LoginScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(null)),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login.png'),
    );
  });

  testWidgets('dashboard golden', (tester) async {
    await pumpScreen(
      tester,
      const DashboardScreen(),
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            Profile.fromJson({
              'first_name': 'Ada',
              'last_name': 'Okafor',
              'email': 'ada@beels.test',
              'status': 'active',
            }),
          ),
        ),
        dashboardControllerProvider
            .overrideWith(() => _FakeDashboardController()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard.png'),
    );
  });

  testWidgets('beels list golden', (tester) async {
    await pumpScreen(
      tester,
      const BeelsScreen(),
      overrides: [
        beelsListControllerProvider
            .overrideWith(() => _FakeBeelsListController()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/beels_list.png'),
    );
  });

  testWidgets('beel detail golden', (tester) async {
    await pumpScreen(
      tester,
      const BeelDetailScreen(id: 27),
      overrides: [
        beelDetailControllerProvider
            .overrideWith(() => _FakeBeelDetailController()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/beel_detail.png'),
    );
  });
}