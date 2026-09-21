import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/envelope.dart';
import '../../../core/api/paginated.dart';
import '../../../core/providers.dart';
import '../models/contribution.dart';

/// Backend access for beels (contributions).
class BeelsRepository {
  BeelsRepository(this._client);

  final ApiClient _client;

  /// GET /contributions — paginated list of the organizer's beels.
  Future<Paginated<Contribution>> list({int page = 1, int perPage = 20}) async {
    final json = await _client.get(
      '/contributions',
      query: {'page': page, 'per_page': perPage},
    );
    return parseListResponse(json);
  }

  /// Parses the paginated contributions envelope.
  static Paginated<Contribution> parseListResponse(dynamic json) =>
      Paginated.parse(json, Contribution.fromJson);

  /// GET /contributions/:id — single beel with contributors + beneficiaries.
  Future<Contribution> get(int id) async {
    final json = await _client.get('/contributions/$id');
    return envelope(json, Contribution.fromJson);
  }

  /// POST /contributions — closed beel with contributors + beneficiaries.
  Future<Contribution> create({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) async {
    final json = await _client.post(
      '/contributions',
      body: buildClosedPayload(
        name: name,
        amount: amount,
        recurrenceType: recurrenceType,
        dayOfWeek: dayOfWeek,
        dayOfMonth: dayOfMonth,
        contributors: contributors,
        beneficiaries: beneficiaries,
      ),
    );
    return envelope(json, Contribution.fromJson);
  }

  /// POST /contributions/open — open-link beel joined via payment link.
  Future<Contribution> createOpen({
    required String name,
    required num amount,
    num? amountPerContributor,
    int? expectedContributors,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<BeneficiaryInput> beneficiaries,
  }) async {
    final json = await _client.post(
      '/contributions/open',
      body: buildOpenPayload(
        name: name,
        amount: amount,
        amountPerContributor: amountPerContributor,
        expectedContributors: expectedContributors,
        recurrenceType: recurrenceType,
        dayOfWeek: dayOfWeek,
        dayOfMonth: dayOfMonth,
        beneficiaries: beneficiaries,
      ),
    );
    return envelope(json, Contribution.fromJson);
  }

  /// Payload for POST /contributions. Null keys are omitted.
  static Map<String, dynamic> buildClosedPayload({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'recurrence_type': recurrenceType,
      // Backend rule: day_of_week is only meaningful for weekly beels and
      // day_of_month for monthly ones; sending both for other recurrences
      // is rejected.
      if (recurrenceType == 'weekly') 'day_of_week': dayOfWeek,
      if (recurrenceType == 'monthly') 'day_of_month': dayOfMonth,
      'contributors': [for (final contributor in contributors) contributor.toJson()],
      'beneficiaries': [
        for (final beneficiary in beneficiaries) beneficiary.toJson(),
      ],
    }..removeWhere((_, value) => value == null);
  }

  /// Payload for POST /contributions/open. Null keys are omitted.
  static Map<String, dynamic> buildOpenPayload({
    required String name,
    required num amount,
    num? amountPerContributor,
    int? expectedContributors,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<BeneficiaryInput> beneficiaries,
  }) {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'amount_per_contributor': amountPerContributor,
      'expected_contributors': expectedContributors,
      'recurrence_type': recurrenceType,
      if (recurrenceType == 'weekly') 'day_of_week': dayOfWeek,
      if (recurrenceType == 'monthly') 'day_of_month': dayOfMonth,
      'beneficiaries': [
        for (final beneficiary in beneficiaries) beneficiary.toJson(),
      ],
    }..removeWhere((_, value) => value == null);
  }

  /// PATCH /contributions/:id/cancel — stop a recurring beel.
  Future<void> cancel(int id) async {
    await _client.patch('/contributions/$id/cancel');
  }

  /// GET /contributions/:id/retry — retry a failed beel.
  Future<void> retry(int id) async {
    await _client.get('/contributions/$id/retry');
  }

  /// POST /contributions/:cid/beneficiary/:bid/disburse.
  Future<void> disburse({
    required int contributionId,
    required int beneficiaryId,
  }) async {
    await _client.post(
      '/contributions/$contributionId/beneficiary/$beneficiaryId/disburse',
    );
  }

  /// DELETE /contributions/remove-contributor/:id.
  Future<void> removeContributor(int contributorId) async {
    await _client.delete('/contributions/remove-contributor/$contributorId');
  }

  /// GET /contributions/my-participation — beels the user paid into.
  Future<List<Participation>> myParticipation() async {
    final json = await _client.get('/contributions/my-participation');
    return envelopeList(json, Participation.fromJson);
  }
}

final beelsRepositoryProvider = Provider<BeelsRepository>((ref) {
  return BeelsRepository(ref.watch(apiClientProvider));
});