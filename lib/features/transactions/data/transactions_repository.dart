import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../../../core/providers.dart';
import '../models/transaction.dart';

/// Backend access for the transaction history.
class TransactionsRepository {
  TransactionsRepository(this._client);

  final ApiClient _client;

  /// GET /transactions — paginated history, newest first.
  Future<Paginated<Transaction>> list(
      {int page = 1, int perPage = 20}) async {
    final json = await _client.get(
      '/transactions',
      query: {'page': page, 'per_page': perPage},
    );
    return parseListResponse(json);
  }

  /// Parses the paginated transactions envelope.
  static Paginated<Transaction> parseListResponse(dynamic json) =>
      Paginated.parse(json, Transaction.fromJson);
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(apiClientProvider));
});