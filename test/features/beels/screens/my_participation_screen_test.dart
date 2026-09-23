import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/models/group_health.dart';
import 'package:beels_mobile/features/beels/screens/my_participation_screen.dart';

class _FakeBeelsRepository implements BeelsRepository {
  _FakeBeelsRepository({this.rows = const [], this.error});

  final List<Participation> rows;
  final Object? error;
  int calls = 0;

  @override
  Future<List<Participation>> myParticipation() async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return rows;
  }

  @override
  Future<GroupHealth?> groupHealth(int id) async => null;

  @override
  Future<QuickDebitActivation> initiateQuickDebit({
    required String identifier,
    required String bankCode,
    required String accountNumber,
  }) async =>
      QuickDebitActivation();

  @override
  Future<InterveneResult> intervene(
    int id, {
    required String interventionKey,
  }) async =>
      const InterveneResult();

  @override
  Future<Paginated<Contribution>> list({int page = 1, int perPage = 20}) async =>
      Paginated.parse(const {}, Contribution.fromJson);

  @override
  Future<Contribution> get(int id) async => Contribution.fromJson(const {});

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
      Contribution.fromJson(const {});

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
      Contribution.fromJson(const {});

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> retry(int id) async {}

  @override
  Future<void> disburse({
    required int contributionId,
    required int beneficiaryId,
  }) async {}

  @override
  Future<void> removeContributor(int contributorId) async {}
}

Participation _row({
  String name = 'Family Savings',
  String status = 'active',
}) =>
    Participation.fromJson({
      'contributor_id': 35,
      'status': status,
      'expected_amount': 5000,
      'amount_paid': 15000,
      'outstanding': 5000,
      'pending_count': 2,
      'last_payment_at': '2026-09-14T10:00:00.000Z',
      'contribution': {
        'id': 29,
        'name': name,
        'status': 'active',
        'next_occurrence': '2026-09-28T04:15:07.000Z',
      },
    });

Future<void> _pump(
  WidgetTester tester, {
  required _FakeBeelsRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [beelsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: MyParticipationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders participation rows with dues and dates',
      (tester) async {
    await _pump(
      tester,
      repository: _FakeBeelsRepository(rows: [_row()]),
    );

    expect(find.text('Family Savings'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
    expect(find.textContaining('outstanding'), findsOneWidget);
    expect(find.textContaining('2 pending payments'), findsOneWidget);
    expect(find.textContaining('Next'), findsOneWidget);
  });

  testWidgets('empty state explains that nothing has been joined yet',
      (tester) async {
    await _pump(tester, repository: _FakeBeelsRepository(rows: []));

    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('errors surface with a retry that refetches', (tester) async {
    final repository = _FakeBeelsRepository(
      error: const ApiException('Offline', statusCode: 0),
    );
    await _pump(tester, repository: repository);

    expect(find.text('Offline'), findsOneWidget);
    expect(repository.calls, 1);
  });
}