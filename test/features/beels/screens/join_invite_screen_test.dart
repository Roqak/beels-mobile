import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/beels/data/beels_repository.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/models/group_health.dart';
import 'package:beels_mobile/features/beels/models/invite.dart';
import 'package:beels_mobile/features/beels/screens/join_invite_screen.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._profile);

  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;
}

class _FakeBeelsRepository implements BeelsRepository {
  _FakeBeelsRepository({this.preview, this.acceptResult, this.acceptError});

  final InvitePreview? preview;
  final InviteAcceptResult? acceptResult;
  final Object? acceptError;
  final List<String> acceptedTokens = <String>[];

  @override
  Future<InvitePreview> previewInvite(String token) async {
    final value = preview;
    if (value == null) {
      throw const ApiException('Invite not found', statusCode: 404);
    }
    return value;
  }

  @override
  Future<InviteAcceptResult> acceptInvite(String token) async {
    final error = acceptError;
    if (error != null) throw error;
    acceptedTokens.add(token);
    return acceptResult!;
  }

  @override
  Future<Paginated<Contribution>> list({int page = 1, int perPage = 20}) =>
      throw UnimplementedError();

  @override
  Future<Contribution> get(int id) => throw UnimplementedError();

  @override
  Future<Contribution> create({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancel(int id) => throw UnimplementedError();

  @override
  Future<void> retry(int id) => throw UnimplementedError();

  @override
  Future<void> disburse({
    required int contributionId,
    required int beneficiaryId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> removeContributor(int contributorId) =>
      throw UnimplementedError();

  @override
  Future<QuickDebitActivation> initiateQuickDebit({
    required String identifier,
    required String bankCode,
    required String accountNumber,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Participation>> myParticipation() => throw UnimplementedError();

  @override
  Future<GroupHealth?> groupHealth(int id) => throw UnimplementedError();

  @override
  Future<InterveneResult> intervene(
    int id, {
    required String interventionKey,
  }) =>
      throw UnimplementedError();

  @override
  Future<BeelInvite> createInvite({
    required int contributionId,
    required int maxUses,
  }) =>
      throw UnimplementedError();
}

const _preview = InvitePreview(
  beelName: 'Family Savings',
  organizerFirstName: 'Chuka',
  organizerLastName: 'Obi',
  shareAmount: 1500,
  slotsLeft: 7,
);

final _signedInProfile = Profile.fromJson({'first_name': 'Ada'});

Future<void> _pump(
  WidgetTester tester, {
  required _FakeBeelsRepository repository,
  Profile? profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        beelsRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(profile),
        ),
      ],
      child: const MaterialApp(home: JoinInviteScreen(token: 'tok42')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out friend sees the preview and a sign-in prompt',
      (tester) async {
    await _pump(tester, repository: _FakeBeelsRepository(preview: _preview));

    expect(find.text('Join Family Savings'), findsWidgets);
    expect(
      find.textContaining('Chuka O. invited you'),
      findsOneWidget,
    );
    expect(find.text('₦1,500'), findsOneWidget);
    expect(find.text('Sign in to join'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('signed-in friend joins with one tap', (tester) async {
    final repo = _FakeBeelsRepository(
      preview: _preview,
      acceptResult: const InviteAcceptResult(
        contributorId: 77,
        beelName: 'Family Savings',
        unitAmount: 1500,
        slotsLeft: 6,
      ),
    );
    await _pump(tester, repository: repo, profile: _signedInProfile);
    // Any non-null profile marks the session as authenticated in the screen.

    await tester.tap(find.text('Join beel'));
    await tester.pumpAndSettle();

    expect(repo.acceptedTokens, ['tok42']);
    expect(find.text("You're in!"), findsOneWidget);
    expect(find.textContaining('Your share:'), findsOneWidget);
  });

  testWidgets('accept failures surface the API message', (tester) async {
    final repo = _FakeBeelsRepository(
      preview: _preview,
      acceptError: const ApiException('Beel is not active', statusCode: 400),
    );
    await _pump(tester, repository: repo, profile: _signedInProfile);

    await tester.tap(find.text('Join beel'));
    await tester.pumpAndSettle();

    expect(repo.acceptedTokens, isEmpty);
    expect(find.text('Beel is not active'), findsOneWidget);
    expect(find.text("You're in!"), findsNothing);
  });

  testWidgets('a spent invite shows the full state instead of the form',
      (tester) async {
    await _pump(
      tester,
      repository: _FakeBeelsRepository(
        preview: const InvitePreview(
          beelName: 'Family Savings',
          organizerFirstName: 'Chuka',
          organizerLastName: 'Obi',
          slotsLeft: 0,
        ),
      ),
    );

    expect(find.text('Invite full'), findsOneWidget);
    expect(find.text('Sign in to join'), findsNothing);
  });
}