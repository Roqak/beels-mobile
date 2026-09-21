import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../data/transactions_repository.dart';
import '../models/transaction.dart';

/// Cumulative state for the paginated transactions list.
class TransactionsListState {
  const TransactionsListState({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<Transaction> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

/// Paginated list of the user's transactions with infinite scroll support.
class TransactionsListController extends AsyncNotifier<TransactionsListState> {
  static const perPage = 20;

  bool _loadingMore = false;

  @override
  Future<TransactionsListState> build() async {
    final page = await ref
        .watch(transactionsRepositoryProvider)
        .list(page: 1, perPage: perPage);
    return _fromPaginated(page);
  }

  TransactionsListState _fromPaginated(Paginated<Transaction> page) =>
      TransactionsListState(
        items: page.items,
        page: page.page,
        lastPage: page.lastPage,
        total: page.total,
      );

  /// Reloads the first page, keeping current data visible while refreshing.
  Future<void> refresh() async {
    state = const AsyncLoading<TransactionsListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _fromPaginated(
        await ref
            .read(transactionsRepositoryProvider)
            .list(page: 1, perPage: perPage),
      );
    });
  }

  /// Appends the next page when one exists. No-op while another load runs.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _loadingMore || !current.hasMore) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(transactionsRepositoryProvider)
          .list(page: current.page + 1, perPage: perPage);
      if (state.valueOrNull == null) return;
      state = AsyncData(TransactionsListState(
        items: [...current.items, ...next.items],
        page: next.page,
        lastPage: next.lastPage,
        total: next.total,
      ));
    } on Object catch (error, stackTrace) {
      if (current.items.isEmpty) {
        state = AsyncError<TransactionsListState>(error, stackTrace);
      }
    } finally {
      _loadingMore = false;
    }
  }
}

final transactionsListControllerProvider =
    AsyncNotifierProvider<TransactionsListController, TransactionsListState>(
        TransactionsListController.new);
