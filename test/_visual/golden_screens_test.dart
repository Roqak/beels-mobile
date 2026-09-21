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
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';
import 'package:beels_mobile/features/groups/screens/groups_screen.dart';
import 'package:beels_mobile/features/groups/screens/create_group_screen.dart';
import 'package:beels_mobile/features/payments/controllers/mandate_setup_controller.dart';
import 'package:beels_mobile/features/payments/controllers/mandates_controller.dart';
import 'package:beels_mobile/features/payments/models/bank.dart';
import 'package:beels_mobile/features/payments/models/payment_mandate.dart';
import 'package:beels_mobile/features/payments/screens/mandate_list_screen.dart';
import 'package:beels_mobile/features/payments/screens/mandate_setup_screen.dart';
import 'package:beels_mobile/features/groups/screens/group_detail_screen.dart';
import 'package:beels_mobile/features/beels/create/beel_draft.dart';
import 'package:beels_mobile/features/beels/create/beel_draft_controller.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/screens/create_beel_screen.dart';
import 'package:beels_mobile/features/auth/screens/lock_screen.dart';
import 'package:beels_mobile/features/auth/screens/register_screen.dart';
import 'package:beels_mobile/features/auth/controllers/session_lock_controller.dart';
import 'package:beels_mobile/features/auth/widgets/biometric_offer.dart';
import 'package:beels_mobile/features/profile/screens/profile_screen.dart';
import 'package:beels_mobile/features/transactions/controllers/transactions_controllers.dart';
import 'package:beels_mobile/features/transactions/models/transaction.dart';
import 'package:beels_mobile/features/transactions/screens/transactions_screen.dart';
import 'package:beels_mobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:beels_mobile/features/shell/app_shell.dart';

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
          (item) =>
              item is Map ? item.cast<String, dynamic>() : <String, dynamic>{},
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

class _FakeTxController extends TransactionsListController {
  @override
  Future<TransactionsListState> build() async {
    // Fixed instants keep the golden stable across runs and days.
    final now = DateTime(2026, 5, 4, 9, 30);
    Transaction tx(int id, String type, num amt, String status, String beel,
            DateTime at) =>
        Transaction(
          id: id,
          type: type,
          amount: amt,
          status: status,
          createdAt: at,
          reference: 'REF-$id',
          beelName: beel,
        );
    return TransactionsListState(
      items: [
        tx(1, 'deposit', 15000, 'successful', 'Family Savings', now),
        tx(2, 'withdrawal', 8000, 'pending', 'Market Savings', now),
        tx(3, 'deposit', 5000, 'successful', 'Weekly Ajo',
            now.subtract(const Duration(days: 1))),
        tx(4, 'deposit', 2500, 'failed', 'Birthday Fund',
            now.subtract(const Duration(days: 5))),
      ],
      page: 1,
      lastPage: 1,
      total: 4,
    );
  }
}

class _FakeGroupsController extends GroupsController {
  @override
  Future<List<Group>> build() async => [
        Group.fromJson({
          'id': 1,
          'name': 'Okafor Family',
          'description': 'Monthly family contributions',
          'members_count': 5,
          'members': [
            {'id': 1, 'first_name': 'Ada', 'last_name': 'Okafor'},
            {'id': 2, 'first_name': 'Bode', 'last_name': 'Aliu'},
            {'id': 3, 'first_name': 'Chi', 'last_name': 'Eze'},
          ],
        }),
        Group.fromJson({
          'id': 2,
          'name': 'Market Women',
          'members_count': 1,
        }),
      ];
}

class _FakeGroupDetail extends GroupDetailController {
  @override
  Future<Group> build(int arg) async => Group.fromJson({
        'id': 1,
        'name': 'Okafor Family',
        'description': 'Monthly family contributions',
        'invite_link': 'https://beels.ng/groups/join/abc123',
        'created_at': '2026-05-04T09:15:00.000Z',
        'members_count': 3,
        'members': [
          {
            'id': 1,
            'first_name': 'Ada',
            'last_name': 'Okafor',
            'email': 'ada@beels.test'
          },
          {
            'id': 2,
            'first_name': 'Bode',
            'last_name': 'Aliu',
            'phone_number': '08023456789'
          },
          {
            'id': 3,
            'first_name': 'Chi',
            'last_name': 'Eze',
            'email': 'chi@beels.test'
          },
        ],
      });
}

final _goldenNow = DateTime(2026, 9, 21);

Map<String, dynamic> _flowRow(String type, num amount, int daysAgo) => {
      'type': type,
      'amount': amount,
      'status': 'successful',
      'created_at':
          _goldenNow.subtract(Duration(days: daysAgo)).toIso8601String(),
    };

final _goldenActivity = [
  _flowRow('deposit', 50000, 27),
  _flowRow('deposit', 30000, 22),
  _flowRow('withdrawal', 15000, 19),
  _flowRow('deposit', 60000, 14),
  _flowRow('deposit', 25000, 9),
  _flowRow('withdrawal', 20000, 6),
  _flowRow('deposit', 40000, 2),
];

final _activityOverrides = <Override>[
  activityRowsProvider.overrideWith((ref) async => _goldenActivity),
  flowClockProvider.overrideWithValue(() => _goldenNow),
];

class _PresetDraft extends BeelDraftController {
  _PresetDraft(this.preset);
  final BeelDraft preset;
  @override
  BeelDraft build() => preset;
}

const _closedDraft = BeelDraft(
  name: 'Family rent',
  amount: '60000',
  recurrenceType: 'weekly',
  dayOfWeek: 'friday',
  contributors: [
    DraftContributor(
      id: 1,
      firstName: 'Ada',
      lastName: 'Obi',
      email: 'ada@beels.test',
      phone: '08012345678',
      amount: '40000',
    ),
    DraftContributor(
      id: 2,
      firstName: 'Bode',
      lastName: 'Aliu',
      email: 'bode@beels.test',
      phone: '08023456789',
      amount: '20000',
    ),
  ],
  beneficiaries: [
    DraftBeneficiary(
      id: 3,
      name: 'Ada Obi',
      accountNumber: '0123456789',
      bankCode: '058',
      bankName: 'GTBank',
    ),
  ],
  nextId: 4,
);

final _blankPayoutDraft = _closedDraft.copyWith(
  beneficiaries: const [DraftBeneficiary(id: 3)],
);

final _splitPayoutDraft = _closedDraft.copyWith(
  beneficiaries: const [
    DraftBeneficiary(
      id: 3,
      name: 'Ada Obi',
      accountNumber: '0123456789',
      bankCode: '058',
      bankName: 'GTBank',
      amount: '35000',
    ),
    DraftBeneficiary(
      id: 4,
      name: 'Chi Eze',
      accountNumber: '2034567890',
      bankCode: '044',
      bankName: 'Access Bank',
      amount: '20000',
    ),
  ],
  nextId: 5,
);

const _openDraft = BeelDraft(
  mode: BeelMode.open,
  name: 'Office party',
  amount: '60000',
  expectedContributors: '4',
  beneficiaries: [
    DraftBeneficiary(
      id: 1,
      name: 'Ada Obi',
      accountNumber: '0123456789',
      bankCode: '058',
      bankName: 'GTBank',
    ),
  ],
  nextId: 2,
);

class _GoldenBeels implements BeelsRepository {
  @override
  Future<Contribution> createOpen({
    required String name,
    required num amount,
    num? amountPerContributor,
    int? expectedContributors,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<BeneficiaryInput> beneficiaries,
  }) async =>
      Contribution(
          id: 1,
          name: name,
          contributionMode: 'open_link',
          paymentLinkToken: 'tok');

  @override
  Future<Contribution> create({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) async =>
      Contribution(name: name);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _createOverrides(BeelDraft draft) => [
      beelDraftProvider.overrideWith(() => _PresetDraft(draft)),
      beelsRepositoryProvider.overrideWithValue(_GoldenBeels()),
      banksProvider.overrideWith((ref) async => const [
            Bank(id: 1, name: 'GTBank', cbnCode: '058'),
          ]),
    ];

class _HiddenBalances extends HideBalancesController {
  @override
  bool build() => true;
}

class _LockedSession extends SessionLockController {
  @override
  SessionLockState build() =>
      const SessionLockState(supported: true, enabled: true, locked: true);

  @override
  Future<bool> unlock() async => false;
}

class _FakeSetup extends MandateSetupController {
  _FakeSetup(this.initial);
  final MandateSetupState initial;
  @override
  MandateSetupState build() => initial;
}

class _FakeMandates extends MandatesController {
  @override
  Future<List<PaymentMandate>> build() async => [
        PaymentMandate(
            id: 1,
            accountNumber: '0123456789',
            bankName: 'GTBank',
            status: 'active'),
        PaymentMandate(
            id: 2,
            accountNumber: '2034567890',
            bankName: 'Access Bank',
            status: 'pending'),
      ];
}

const _bank = Bank(id: 1, name: 'GTBank', cbnCode: '058');

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
      final first =
          await rootBundle.load('assets/google_fonts/$family-Regular.ttf');
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
        beelsListControllerProvider
            .overrideWith(() => _FakeBeelsListController()),
        ..._activityOverrides,
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
        ..._activityOverrides,
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

  testWidgets('transactions golden', (tester) async {
    await pumpScreen(
      tester,
      const TransactionsScreen(),
      overrides: [
        transactionsListControllerProvider
            .overrideWith(() => _FakeTxController()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/transactions.png'),
    );
  });

  testWidgets('groups golden', (tester) async {
    await pumpScreen(
      tester,
      const GroupsScreen(),
      overrides: [
        groupsListProvider.overrideWith(() => _FakeGroupsController()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/groups.png'),
    );
  });

  testWidgets('profile golden', (tester) async {
    await pumpScreen(
      tester,
      const ProfileScreen(),
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            Profile.fromJson({
              'first_name': 'Ada',
              'last_name': 'Okafor',
              'email': 'ada@beels.test',
              'phone_number': '08012345678',
              'status': 'active',
            }),
          ),
        ),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/profile.png'),
    );
  });

  testWidgets('group detail golden', (tester) async {
    await pumpScreen(
      tester,
      const GroupDetailScreen(id: 1),
      overrides: [
        groupDetailProvider.overrideWith(() => _FakeGroupDetail()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/group_detail.png'),
    );
  });

  testWidgets('register golden', (tester) async {
    await pumpScreen(
      tester,
      const RegisterScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(null)),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/register.png'),
    );
  });

  testWidgets('lock golden', (tester) async {
    await pumpScreen(
      tester,
      const LockScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(null)),
        sessionLockControllerProvider.overrideWith(() => _LockedSession()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/lock.png'),
    );
  });

  group('dark', () {
    setUp(() => BeelsColors.apply(Brightness.dark));
    tearDown(() => BeelsColors.apply(Brightness.light));

    testWidgets('dashboard dark golden', (tester) async {
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
          beelsListControllerProvider
              .overrideWith(() => _FakeBeelsListController()),
          ..._activityOverrides,
        ],
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dashboard_dark.png'),
      );
    });

    testWidgets('transactions dark golden', (tester) async {
      await pumpScreen(
        tester,
        const TransactionsScreen(),
        overrides: [
          transactionsListControllerProvider
              .overrideWith(() => _FakeTxController()),
        ],
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/transactions_dark.png'),
      );
    });

    testWidgets('login dark golden', (tester) async {
      await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthController(null)),
        ],
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_dark.png'),
      );
    });
  });

  testWidgets('mandate setup step 1 golden', (tester) async {
    await pumpScreen(
      tester,
      const MandateSetupScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(null)),
        banksProvider.overrideWith((ref) async => [_bank]),
        mandateSetupControllerProvider.overrideWith(() => _FakeSetup(
            const MandateSetupState(
                selectedBank: _bank,
                accountNumber: '0123456789',
                accountName: 'ADA OKAFOR'))),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mandate_setup_1.png'),
    );
  });

  testWidgets('mandate setup step 2 golden', (tester) async {
    await pumpScreen(
      tester,
      const MandateSetupScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(null)),
        banksProvider.overrideWith((ref) async => [_bank]),
        mandateSetupControllerProvider.overrideWith(() => _FakeSetup(
            const MandateSetupState(
                step: MandateSetupStep.personal,
                selectedBank: _bank,
                accountNumber: '0123456789',
                accountName: 'ADA OKAFOR'))),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mandate_setup_2.png'),
    );
  });

  testWidgets('mandate list golden', (tester) async {
    await pumpScreen(
      tester,
      const MandateListScreen(),
      overrides: [
        mandatesControllerProvider.overrideWith(() => _FakeMandates()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mandate_list.png'),
    );
  });

  testWidgets('create group golden', (tester) async {
    await pumpScreen(tester, const CreateGroupScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_group.png'),
    );
  });

  group('dark more', () {
    setUp(() => BeelsColors.apply(Brightness.dark));
    tearDown(() => BeelsColors.apply(Brightness.light));

    testWidgets('beel detail dark golden', (tester) async {
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
        matchesGoldenFile('goldens/beel_detail_dark.png'),
      );
    });

    testWidgets('profile dark golden', (tester) async {
      await pumpScreen(
        tester,
        const ProfileScreen(),
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              Profile.fromJson({
                'first_name': 'Ada',
                'last_name': 'Okafor',
                'email': 'ada@beels.test',
                'phone_number': '08012345678',
                'status': 'active',
              }),
            ),
          ),
        ],
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/profile_dark.png'),
      );
    });

    testWidgets('group detail dark golden', (tester) async {
      await pumpScreen(
        tester,
        const GroupDetailScreen(id: 1),
        overrides: [
          groupDetailProvider.overrideWith(() => _FakeGroupDetail()),
        ],
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/group_detail_dark.png'),
      );
    });
  });

  testWidgets('biometric offer golden', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(child: BiometricOfferSheet()),
        ),
      ),
      overrides: [
        sessionLockControllerProvider.overrideWith(() => _LockedSession()),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/biometric_offer.png'),
    );
  });

  testWidgets('dashboard hidden balances golden', (tester) async {
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
        beelsListControllerProvider
            .overrideWith(() => _FakeBeelsListController()),
        hideBalancesProvider.overrideWith(() => _HiddenBalances()),
        ..._activityOverrides,
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard_hidden.png'),
    );
  });

  testWidgets('floating nav golden', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: 1,
          onSelect: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/floating_nav.png'),
    );
  });

  testWidgets('floating nav dark golden', (tester) async {
    BeelsColors.apply(Brightness.dark);
    addTearDown(() => BeelsColors.apply(Brightness.light));
    await pumpScreen(
      tester,
      Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: 0,
          onSelect: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/floating_nav_dark.png'),
    );
  });

  Future<void> createStep(
      WidgetTester tester, BeelDraft draft, int steps) async {
    await pumpScreen(
      tester,
      CreateBeelScreen(now: DateTime(2026, 9, 21)),
      overrides: _createOverrides(draft),
    );
    for (var i = 0; i < steps; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
  }

  for (var step = 0; step < 5; step++) {
    testWidgets('create beel step ${step + 1} golden', (tester) async {
      await createStep(tester, _closedDraft, step);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/create_beel_${step + 1}.png'),
      );
    });
  }

  testWidgets('create beel person sheet golden', (tester) async {
    await createStep(tester, _closedDraft, 2);
    await tester.tap(find.text('Add person').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_person_sheet.png'),
    );
  });

  testWidgets('create beel payout empty golden', (tester) async {
    await createStep(tester, _blankPayoutDraft, 3);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_payout_empty.png'),
    );
  });

  testWidgets('create beel account sheet golden', (tester) async {
    await createStep(tester, _blankPayoutDraft, 3);
    await tester.tap(find.text('Add payout account'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_account_sheet.png'),
    );
  });

  testWidgets('create beel payout split golden', (tester) async {
    await createStep(tester, _splitPayoutDraft, 3);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_payout_split.png'),
    );
  });

  testWidgets('create beel open people golden', (tester) async {
    await createStep(tester, _openDraft, 2);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_open_people.png'),
    );
  });

  testWidgets('create beel success golden', (tester) async {
    await createStep(tester, _openDraft, 4);
    await tester.tap(find.text('Create beel'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_beel_success.png'),
    );
  });

  group('dark create', () {
    setUp(() => BeelsColors.apply(Brightness.dark));
    tearDown(() => BeelsColors.apply(Brightness.light));

    testWidgets('create beel people dark golden', (tester) async {
      await createStep(tester, _closedDraft, 2);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/create_beel_people_dark.png'),
      );
    });

    testWidgets('create beel review dark golden', (tester) async {
      await createStep(tester, _closedDraft, 4);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/create_beel_review_dark.png'),
      );
    });
  });
}
